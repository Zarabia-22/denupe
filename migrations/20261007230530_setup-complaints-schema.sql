-- =============================================================================
-- DenuPe: esquema inicial de denuncias ciudadanas
-- -----------------------------------------------------------------------------
-- Contenido:
--   1. Tabla profiles          (perfil ciudadano, vinculado a auth.users)
--   2. Tabla categories        (catálogo público de categorías de denuncia)
--   3. Tabla complaints        (denuncias)
--   4. Tabla complaint_status_history (trazabilidad de estados)
--   5. Tabla notifications     (notificaciones in-app de seguimiento)
--   6. Funciones de soporte, triggers, RLS, grants e índices
--   7. Canal realtime para seguimiento de denuncia
--   8. Seed de categorías
-- =============================================================================

-- =============================================================================
-- 1. profiles
-- =============================================================================
CREATE TABLE public.profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name  TEXT,
  dni        TEXT UNIQUE,
  phone      TEXT,
  district   TEXT,
  role       TEXT NOT NULL DEFAULT 'citizen' CHECK (role IN ('citizen', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 2. categories
-- =============================================================================
CREATE TABLE public.categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 3. complaints
-- =============================================================================
CREATE TABLE public.complaints (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id UUID REFERENCES public.categories(id),
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  address     TEXT,
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  status      TEXT NOT NULL DEFAULT 'recibida'
              CHECK (status IN ('recibida', 'en_revision', 'en_proceso', 'resuelta', 'rechazada', 'archivada')),
  priority    TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('baja', 'normal', 'alta')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 4. complaint_status_history
-- =============================================================================
CREATE TABLE public.complaint_status_history (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id UUID NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
  status       TEXT NOT NULL,
  note         TEXT,
  created_by   UUID REFERENCES auth.users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.complaint_status_history ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 5. notifications
-- =============================================================================
CREATE TABLE public.notifications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  complaint_id UUID REFERENCES public.complaints(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  body         TEXT,
  is_read      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 6a. Funciones de soporte
-- =============================================================================

-- ¿El usuario autenticado es administrador?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- Crea el perfil automáticamente al registrarse un usuario
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, NEW.profile->>'name');
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- Impide que el propio ciudadano cambie su rol (solo admin vía función)
CREATE OR REPLACE FUNCTION public.prevent_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'No puedes cambiar tu rol de usuario';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_profile_before_update
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.prevent_role_change();

-- Publica el cambio de estado de una denuncia en realtime.
-- (El histórico y la notificación los inserta public.update_complaint_status)
CREATE OR REPLACE FUNCTION public.realtime_complaint_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  PERFORM realtime.publish(
    'complaint:' || NEW.id::text,
    'status_changed',
    jsonb_build_object('id', NEW.id, 'status', NEW.status, 'updated_at', NEW.updated_at)
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_complaint_status_change
AFTER UPDATE ON public.complaints
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.realtime_complaint_status_change();

-- Guarda el campo status/priority: solo admins lo modifican (función dedicada)
CREATE OR REPLACE FUNCTION public.guard_complaint_guarded_fields()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF (NEW.status IS DISTINCT FROM OLD.status OR NEW.priority IS DISTINCT FROM OLD.priority OR NEW.user_id IS DISTINCT FROM OLD.user_id)
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tienes permisos para modificar este campo';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_complaint_before_update
BEFORE UPDATE ON public.complaints
FOR EACH ROW
EXECUTE FUNCTION public.guard_complaint_guarded_fields();

-- =============================================================================
-- 6b. Función para que un ADMIN actualice el estado de una denuncia.
--     Único camino permitido para mover el flujo de seguimiento:
--       1) cambia el estado, 2) registra el histórico, 3) crea notificación,
--       4) el trigger publica el evento en realtime.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.update_complaint_status(
  p_complaint_id UUID,
  p_new_status   TEXT,
  p_note         TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_user_id UUID;
  v_old_status TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo administradores pueden actualizar estados';
  END IF;

  IF p_new_status NOT IN ('recibida', 'en_revision', 'en_proceso', 'resuelta', 'rechazada', 'archivada') THEN
    RAISE EXCEPTION 'Estado de denuncia inválido';
  END IF;

  SELECT user_id, status INTO v_user_id, v_old_status
  FROM public.complaints
  WHERE id = p_complaint_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Denuncia no encontrada';
  END IF;

  IF v_old_status = p_new_status THEN
    RETURN;
  END IF;

  UPDATE public.complaints
  SET status = p_new_status
  WHERE id = p_complaint_id;

  INSERT INTO public.complaint_status_history (complaint_id, status, note, created_by)
  VALUES (p_complaint_id, p_new_status, p_note, auth.uid());

  INSERT INTO public.notifications (user_id, complaint_id, title, body)
  VALUES (
    v_user_id,
    p_complaint_id,
    'Tu denuncia cambió de estado',
    'Nuevo estado: ' || p_new_status || CASE WHEN p_note IS NOT NULL THEN ' — ' || p_note ELSE '' END
  );
END;
$$;

-- =============================================================================
-- 6c. Auto-update de updated_at
-- =============================================================================
CREATE TRIGGER profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION system.update_updated_at();

CREATE TRIGGER complaints_updated_at
BEFORE UPDATE ON public.complaints
FOR EACH ROW
EXECUTE FUNCTION system.update_updated_at();

-- =============================================================================
-- 6d. Grants (privilegios SQL)
-- =============================================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT SELECT ON public.categories TO anon, authenticated;

GRANT SELECT ON public.profiles TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM authenticated;
GRANT UPDATE (full_name, dni, phone, district) ON public.profiles TO authenticated;

GRANT SELECT ON public.complaints TO authenticated;
GRANT INSERT ON public.complaints TO authenticated;
REVOKE UPDATE, DELETE ON public.complaints FROM authenticated;
GRANT UPDATE (title, description, category_id, address, latitude, longitude) ON public.complaints TO authenticated;

GRANT SELECT ON public.complaint_status_history TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.complaint_status_history FROM authenticated;

GRANT SELECT ON public.notifications TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.notifications FROM authenticated;
GRANT UPDATE (is_read) ON public.notifications TO authenticated;

-- =============================================================================
-- 6e. RLS policies
-- =============================================================================
-- profiles: solo el dueño (o admin) lee; el dueño actualiza su información
CREATE POLICY "profiles_select_own_or_admin"
ON public.profiles FOR SELECT TO authenticated
USING (id = (SELECT auth.uid()) OR public.is_admin());

CREATE POLICY "profiles_update_own"
ON public.profiles FOR UPDATE TO authenticated
USING (id = (SELECT auth.uid()))
WITH CHECK (id = (SELECT auth.uid()));

-- categories: catálogo público de lectura
CREATE POLICY "categories_public_read"
ON public.categories FOR SELECT TO anon, authenticated
USING (TRUE);

-- complaints: ciudadano ve y crea sus propias denuncias; admin todo
CREATE POLICY "complaints_select_own_or_admin"
ON public.complaints FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()) OR public.is_admin());

CREATE POLICY "complaints_insert_own_or_admin"
ON public.complaints FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT auth.uid()) OR public.is_admin());

CREATE POLICY "complaints_update_own_or_admin"
ON public.complaints FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()) OR public.is_admin())
WITH CHECK (user_id = (SELECT auth.uid()) OR public.is_admin());

-- history: lecturas de denuncias propias (o admin)
CREATE POLICY "history_select_own_complaints"
ON public.complaint_status_history FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.complaints c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid()) OR public.is_admin())
  )
);

-- notifications: solo el dueño lee y marca como leídas
CREATE POLICY "notifications_select_own"
ON public.notifications FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

CREATE POLICY "notifications_update_is_read_own"
ON public.notifications FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

-- =============================================================================
-- 6f. Índices
-- =============================================================================
CREATE INDEX complaints_user_id_idx       ON public.complaints (user_id);
CREATE INDEX complaints_category_id_idx   ON public.complaints (category_id);
CREATE INDEX complaints_status_idx        ON public.complaints (status);
CREATE INDEX notifications_user_id_idx    ON public.notifications (user_id);
CREATE INDEX history_complaint_id_idx     ON public.complaint_status_history (complaint_id);

-- =============================================================================
-- 7. Realtime: patrón de canal para seguimiento por denuncia
-- =============================================================================
INSERT INTO realtime.channels (pattern, description, enabled)
VALUES ('complaint:%', 'Seguimiento individual de denuncias', TRUE)
ON CONFLICT (pattern) DO UPDATE
SET description = EXCLUDED.description,
    enabled = EXCLUDED.enabled;

-- =============================================================================
-- 8. Seed: categorías de denuncias
-- =============================================================================
INSERT INTO public.categories (code, name, description, sort_order) VALUES
  ('alumbrado',      'Alumbrado público',  'Fallas o ausencia de alumbrado en la vía pública', 1),
  ('seguridad',      'Seguridad ciudadana', 'Robos, vandalismo y situaciones que afectan la seguridad', 2),
  ('limpieza',       'Limpieza y residuos', 'Acumulación de basura y mala disposición de residuos', 3),
  ('agua',           'Agua y saneamiento', 'Cortes de agua, fugas o problemas de desagüe', 4),
  ('transito',       'Tránsito y transporte', 'Problemas de señalización y tránsito vehicular', 5),
  ('areas_verdes',   'Parques y áreas verdes', 'Abandono o deterioro de parques y áreas verdes', 6),
  ('infraestructura', 'Vialidad e infraestructura', 'Baches, veredas rotas y daños viales', 7),
  ('otros',          'Otros',              'Otros tipos de denuncias', 99)
ON CONFLICT (code) DO NOTHING;