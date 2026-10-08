-- =============================================================================
-- DenuPe: autoridades receptoras de denuncias + nombres de tablas en español
-- -----------------------------------------------------------------------------
-- 1. Nueva tabla autoridades  (Municipalidad, Comisaría PNP, Serenazgo)
-- 2. Asignación automática de la entidad responsable según la categoría
--    (categorias.autoridad_predeterminada_id + trigger sobre denuncias)
-- 3. RPC asignar_autoridad (solo admin) para reasignar y notificar al ciudadano
-- 4. Renombrado de las tablas de la app a español:
--    profiles -> perfiles
--    categories -> categorias
--    complaints -> denuncias
--    complaint_status_history -> historial_estados
--    notifications -> notificaciones
--    complaint_media -> adjuntos_denuncia
--    (constraints e índices renombrados a la par)
-- 5. Funciones y políticas actualizadas a los nuevos nombres
-- =============================================================================

-- =============================================================================
-- 1. autoridades
-- =============================================================================
CREATE TABLE public.autoridades (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL UNIQUE,
  sigla       TEXT NOT NULL UNIQUE,
  tipo        TEXT NOT NULL CHECK (tipo IN ('municipalidad', 'comisaria', 'serenazgo', 'otro')),
  descripcion TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.autoridades ENABLE ROW LEVEL SECURITY;

CREATE INDEX autoridades_tipo_idx ON public.autoridades (tipo);

CREATE TRIGGER autoridades_updated_at
BEFORE UPDATE ON public.autoridades
FOR EACH ROW
EXECUTE FUNCTION system.update_updated_at();

-- Catálogo público de entidades receptoras.
CREATE POLICY autoridades_public_read
ON public.autoridades FOR SELECT TO anon, authenticated
USING (TRUE);

GRANT SELECT ON public.autoridades TO anon, authenticated;

-- Seed de las tres entidades receptoras.
INSERT INTO public.autoridades (nombre, sigla, tipo, descripcion) VALUES
  ('Municipalidad del Distrito',
   'MUN', 'municipalidad',
   'Recibe denuncias de servicios municipales: alumbrado, limpieza, agua, áreas verdes e infraestructura.'),
  ('Comisaría de la Policía Nacional',
   'PNP', 'comisaria',
   'Recibe denuncias de seguridad ciudadana y tránsito vehicular.'),
  ('Serenazgo del Distrito',
   'SER', 'serenazgo',
   'Recibe denuncias generales y actúa como nexo ante emergencias locales.')
ON CONFLICT (nombre) DO NOTHING;

-- =============================================================================
-- 2. Asignación: categorias.autoridad_predeterminada_id
-- =============================================================================
ALTER TABLE public.categories
  ADD COLUMN autoridad_predeterminada_id UUID REFERENCES public.autoridades(id);

-- Mapeo por defecto: cada categoría define qué entidad la atiende primero.
UPDATE public.categories SET autoridad_predeterminada_id =
  (SELECT id FROM public.autoridades WHERE tipo = 'municipalidad')
  WHERE code IN ('alumbrado', 'limpieza', 'agua', 'areas_verdes', 'infraestructura');

UPDATE public.categories SET autoridad_predeterminada_id =
  (SELECT id FROM public.autoridades WHERE tipo = 'comisaria')
  WHERE code IN ('seguridad', 'transito');

UPDATE public.categories SET autoridad_predeterminada_id =
  (SELECT id FROM public.autoridades WHERE tipo = 'serenazgo')
  WHERE code = 'otros';

-- =============================================================================
-- 3. denuncias.autoridad_id
-- =============================================================================
ALTER TABLE public.complaints
  ADD COLUMN autoridad_id UUID REFERENCES public.autoridades(id);

CREATE INDEX complaints_autoridad_id_idx ON public.complaints (autoridad_id);

-- =============================================================================
-- 4. Renombrado de tablas a español
-- =============================================================================
ALTER TABLE public.profiles                 RENAME TO perfiles;
ALTER TABLE public.categories               RENAME TO categorias;
ALTER TABLE public.complaints               RENAME TO denuncias;
ALTER TABLE public.complaint_status_history RENAME TO historial_estados;
ALTER TABLE public.notifications            RENAME TO notificaciones;
ALTER TABLE public.complaint_media          RENAME TO adjuntos_denuncia;

-- Constraints
ALTER TABLE public.perfiles RENAME CONSTRAINT profiles_pkey         TO perfiles_pkey;
ALTER TABLE public.perfiles RENAME CONSTRAINT profiles_dni_key      TO perfiles_dni_key;
ALTER TABLE public.perfiles RENAME CONSTRAINT profiles_id_fkey      TO perfiles_id_fkey;
ALTER TABLE public.perfiles RENAME CONSTRAINT profiles_role_check   TO perfiles_role_check;

ALTER TABLE public.categorias RENAME CONSTRAINT categories_pkey     TO categorias_pkey;
ALTER TABLE public.categorias RENAME CONSTRAINT categories_code_key TO categorias_code_key;

ALTER TABLE public.denuncias RENAME CONSTRAINT complaints_pkey          TO denuncias_pkey;
ALTER TABLE public.denuncias RENAME CONSTRAINT complaints_user_id_fkey  TO denuncias_user_id_fkey;
ALTER TABLE public.denuncias RENAME CONSTRAINT complaints_category_id_fkey TO denuncias_category_id_fkey;
ALTER TABLE public.denuncias RENAME CONSTRAINT complaints_status_check  TO denuncias_status_check;
ALTER TABLE public.denuncias RENAME CONSTRAINT complaints_priority_check TO denuncias_priority_check;
ALTER TABLE public.denuncias RENAME CONSTRAINT complaints_autoridad_id_fkey TO denuncias_autoridad_id_fkey;

ALTER TABLE public.historial_estados RENAME CONSTRAINT complaint_status_history_pkey           TO historial_estados_pkey;
ALTER TABLE public.historial_estados RENAME CONSTRAINT complaint_status_history_complaint_id_fkey TO historial_estados_complaint_id_fkey;
ALTER TABLE public.historial_estados RENAME CONSTRAINT complaint_status_history_created_by_fkey   TO historial_estados_created_by_fkey;

ALTER TABLE public.notificaciones RENAME CONSTRAINT notifications_pkey            TO notificaciones_pkey;
ALTER TABLE public.notificaciones RENAME CONSTRAINT notifications_user_id_fkey    TO notificaciones_user_id_fkey;
ALTER TABLE public.notificaciones RENAME CONSTRAINT notifications_complaint_id_fkey TO notificaciones_complaint_id_fkey;

ALTER TABLE public.adjuntos_denuncia RENAME CONSTRAINT complaint_media_pkey               TO adjuntos_denuncia_pkey;
ALTER TABLE public.adjuntos_denuncia RENAME CONSTRAINT complaint_media_complaint_id_fkey  TO adjuntos_denuncia_complaint_id_fkey;
ALTER TABLE public.adjuntos_denuncia RENAME CONSTRAINT complaint_media_user_id_fkey       TO adjuntos_denuncia_user_id_fkey;
ALTER TABLE public.adjuntos_denuncia RENAME CONSTRAINT complaint_media_media_type_check   TO adjuntos_denuncia_media_type_check;

-- Índices independientes
ALTER INDEX public.complaints_user_id_idx          RENAME TO denuncias_user_id_idx;
ALTER INDEX public.complaints_category_id_idx      RENAME TO denuncias_categoria_id_idx;
ALTER INDEX public.complaints_status_idx           RENAME TO denuncias_estado_idx;
ALTER INDEX public.complaints_autoridad_id_idx     RENAME TO denuncias_autoridad_id_idx;
ALTER INDEX public.history_complaint_id_idx        RENAME TO historial_estados_complaint_id_idx;
ALTER INDEX public.notifications_user_id_idx       RENAME TO notificaciones_user_id_idx;
ALTER INDEX public.notifications_user_created_idx  RENAME TO notificaciones_user_created_idx;
ALTER INDEX public.complaint_media_complaint_id_idx RENAME TO adjuntos_denuncia_complaint_id_idx;

-- =============================================================================
-- 5. Backfill: asignar entidad a las denuncias existentes y exigir el campo
-- =============================================================================
UPDATE public.denuncias d
SET autoridad_id = c.autoridad_predeterminada_id
FROM public.categorias c
WHERE c.id = d.category_id
  AND d.autoridad_id IS NULL;

UPDATE public.denuncias
SET autoridad_id = (SELECT id FROM public.autoridades WHERE tipo = 'municipalidad')
WHERE autoridad_id IS NULL;

ALTER TABLE public.denuncias ALTER COLUMN autoridad_id SET NOT NULL;

-- =============================================================================
-- 6. Funciones actualizadas a los nuevos nombres de tablas
-- =============================================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  INSERT INTO public.perfiles (id, full_name)
  VALUES (NEW.id, NEW.profile->>'name');
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.prevent_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role
     AND (SELECT auth.uid()) IS NOT NULL
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'No puedes cambiar tu rol de usuario';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.guard_complaint_guarded_fields()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF (NEW.status IS DISTINCT FROM OLD.status
      OR NEW.priority IS DISTINCT FROM OLD.priority
      OR NEW.user_id IS DISTINCT FROM OLD.user_id
      OR NEW.autoridad_id IS DISTINCT FROM OLD.autoridad_id)
     AND (SELECT auth.uid()) IS NOT NULL
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tienes permisos para modificar este campo';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_complaint_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  INSERT INTO public.notificaciones (user_id, complaint_id, title, body)
  VALUES (
    NEW.user_id,
    NEW.id,
    'Denuncia registrada',
    'Tu denuncia "' || NEW.title || '" quedó registrada con estado: '
      || public.complaint_status_label(NEW.status) || '.'
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_complaint_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  INSERT INTO public.notificaciones (user_id, complaint_id, title, body)
  VALUES (
    NEW.user_id,
    NEW.id,
    'Tu denuncia cambió de estado',
    'Tu denuncia "' || NEW.title || '" ahora está en: '
      || public.complaint_status_label(NEW.status) || '.'
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_complaint_status(
  p_complaint_id UUID,
  p_new_status   TEXT,
  p_note         TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_old_status TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo administradores pueden actualizar estados';
  END IF;

  IF p_new_status NOT IN ('recibida', 'en_revision', 'en_proceso', 'resuelta', 'rechazada', 'archivada') THEN
    RAISE EXCEPTION 'Estado de denuncia inválido';
  END IF;

  SELECT status INTO v_old_status
  FROM public.denuncias
  WHERE id = p_complaint_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Denuncia no encontrada';
  END IF;

  IF v_old_status = p_new_status THEN
    RETURN;
  END IF;

  UPDATE public.denuncias
  SET status = p_new_status
  WHERE id = p_complaint_id;

  INSERT INTO public.historial_estados (complaint_id, status, note, created_by)
  VALUES (p_complaint_id, p_new_status, p_note, auth.uid());
END;
$$;

-- =============================================================================
-- 7. Asignación automática de la entidad al crear la denuncia
-- =============================================================================
CREATE OR REPLACE FUNCTION public.asignar_autoridad_predeterminada()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_autoridad UUID;
BEGIN
  IF NEW.autoridad_id IS NULL THEN
    SELECT autoridad_predeterminada_id INTO v_autoridad
    FROM public.categorias
    WHERE id = NEW.category_id;

    NEW.autoridad_id := COALESCE(
      v_autoridad,
      (SELECT id FROM public.autoridades WHERE tipo = 'municipalidad')
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_denuncia_before_insert
BEFORE INSERT ON public.denuncias
FOR EACH ROW
EXECUTE FUNCTION public.asignar_autoridad_predeterminada();

-- =============================================================================
-- 8. RPC: reasignación de la entidad responsable (solo admin)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.asignar_autoridad(
  p_denuncia_id  UUID,
  p_autoridad_id UUID
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_user_id        UUID;
  v_estado         TEXT;
  v_autoridad_actual UUID;
  v_autoridad_nombre TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo administradores pueden asignar autoridades';
  END IF;

  SELECT nombre INTO v_autoridad_nombre
  FROM public.autoridades
  WHERE id = p_autoridad_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Autoridad inexistente';
  END IF;

  SELECT user_id, status, autoridad_id
    INTO v_user_id, v_estado, v_autoridad_actual
  FROM public.denuncias
  WHERE id = p_denuncia_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Denuncia no encontrada';
  END IF;

  IF v_autoridad_actual IS NOT DISTINCT FROM p_autoridad_id THEN
    RETURN;
  END IF;

  UPDATE public.denuncias
  SET autoridad_id = p_autoridad_id
  WHERE id = p_denuncia_id;

  INSERT INTO public.historial_estados (complaint_id, status, note, created_by)
  VALUES (p_denuncia_id, v_estado, 'Asignada a ' || v_autoridad_nombre, auth.uid());

  INSERT INTO public.notificaciones (user_id, complaint_id, title, body)
  VALUES (
    v_user_id,
    p_denuncia_id,
    'Tu denuncia fue asignada',
    'Tu denuncia fue asignada a: ' || v_autoridad_nombre || '.'
  );
END;
$$;

-- =============================================================================
-- 9. Políticas actualizadas a los nuevos nombres de tablas
-- =============================================================================
DROP POLICY IF EXISTS history_select_own_complaints ON public.historial_estados;
CREATE POLICY history_select_own_complaints
ON public.historial_estados FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.denuncias c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid()) OR public.is_admin())
  )
);

DROP POLICY IF EXISTS complaint_media_select_own_or_admin ON public.adjuntos_denuncia;
CREATE POLICY complaint_media_select_own_or_admin
ON public.adjuntos_denuncia FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.denuncias c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid()) OR public.is_admin())
  )
);

DROP POLICY IF EXISTS complaint_media_insert_own_or_admin ON public.adjuntos_denuncia;
CREATE POLICY complaint_media_insert_own_or_admin
ON public.adjuntos_denuncia FOR INSERT TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.denuncias c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid()) OR public.is_admin())
  )
);

DROP POLICY IF EXISTS complaint_media_delete_own_or_admin ON public.adjuntos_denuncia;
CREATE POLICY complaint_media_delete_own_or_admin
ON public.adjuntos_denuncia FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.denuncias c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid()) OR public.is_admin())
  )
);