-- =============================================================================
-- DenuPe: rol funcionario municipal
-- -----------------------------------------------------------------------------
-- Usuarios que trabajan para una entidad (municipalidad, comisaría, serenazgo):
--   1. perfiles.autoridad_id  -> entidad a la que pertenecen
--   2. rol 'funcionario'      -> nuevo rol permitido
--   3. Helpers is_funcionario / is_funcionario_de
--   4. RLS: funcionarios ven las denuncias asignadas a SU entidad
--      (denuncias, historial y adjuntos); no pueden cambiar autoridad.
--   5. guard: solo STATUS es editable por la entidad responsable
--      (priority, user_id y autoridad_id siguen siendo exclusivos de admin).
--   6. update_complaint_status acepta a la entidad responsable.
--   7. RPC asignar_funcionario (admin) para vincular perfil + entidad.
-- =============================================================================

-- =============================================================================
-- 1. perfiles: entidad + rol funcionario
-- =============================================================================
ALTER TABLE public.perfiles
  ADD COLUMN autoridad_id UUID REFERENCES public.autoridades(id);

ALTER TABLE public.perfiles
  DROP CONSTRAINT perfiles_role_check;

ALTER TABLE public.perfiles
  ADD CONSTRAINT perfiles_role_check
  CHECK (role IN ('citizen', 'admin', 'funcionario'));

-- =============================================================================
-- 2. Helpers de rol
-- =============================================================================
CREATE OR REPLACE FUNCTION public.is_funcionario()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles
    WHERE id = auth.uid() AND role = 'funcionario' AND autoridad_id IS NOT NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.is_funcionario_de(p_autoridad_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT p_autoridad_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE id = auth.uid()
        AND role = 'funcionario'
        AND autoridad_id = p_autoridad_id
    );
$$;

-- =============================================================================
-- 3. RLS: la entidad responsable ve las denuncias que le corresponden
-- =============================================================================
DROP POLICY IF EXISTS complaints_select_own_or_admin ON public.denuncias;
CREATE POLICY denuncias_select_own_admin_funcionario
ON public.denuncias FOR SELECT TO authenticated
USING (
  user_id = (SELECT auth.uid())
  OR public.is_admin()
  OR public.is_funcionario_de(autoridad_id)
);

DROP POLICY IF EXISTS history_select_own_complaints ON public.historial_estados;
CREATE POLICY historial_select_own_admin_funcionario
ON public.historial_estados FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.denuncias c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid())
           OR public.is_admin()
           OR public.is_funcionario_de(c.autoridad_id))
  )
);

DROP POLICY IF EXISTS complaint_media_select_own_or_admin ON public.adjuntos_denuncia;
CREATE POLICY adjuntos_select_own_admin_funcionario
ON public.adjuntos_denuncia FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.denuncias c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid())
           OR public.is_admin()
           OR public.is_funcionario_de(c.autoridad_id))
  )
);

-- =============================================================================
-- 4. Guard: la entidad responsable solo puede cambiar STATUS
-- =============================================================================
CREATE OR REPLACE FUNCTION public.guard_complaint_guarded_fields()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF (NEW.status IS DISTINCT FROM OLD.status)
     AND (SELECT auth.uid()) IS NOT NULL
     AND NOT public.is_admin()
     AND NOT public.is_funcionario_de(NEW.autoridad_id) THEN
    RAISE EXCEPTION 'Solo la entidad responsable puede cambiar el estado';
  END IF;

  IF (NEW.priority IS DISTINCT FROM OLD.priority
      OR NEW.user_id IS DISTINCT FROM OLD.user_id
      OR NEW.autoridad_id IS DISTINCT FROM OLD.autoridad_id)
     AND (SELECT auth.uid()) IS NOT NULL
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tienes permisos para modificar este campo';
  END IF;

  RETURN NEW;
END;
$$;

-- =============================================================================
-- 5. update_complaint_status: admite a la entidad responsable
-- =============================================================================
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
  v_user_id      UUID;
  v_old_status   TEXT;
  v_autoridad_id UUID;
BEGIN
  IF p_new_status NOT IN ('recibida', 'en_revision', 'en_proceso', 'resuelta', 'rechazada', 'archivada') THEN
    RAISE EXCEPTION 'Estado de denuncia inválido';
  END IF;

  SELECT user_id, status, autoridad_id
    INTO v_user_id, v_old_status, v_autoridad_id
  FROM public.denuncias
  WHERE id = p_complaint_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Denuncia no encontrada';
  END IF;

  IF NOT public.is_admin() AND NOT public.is_funcionario_de(v_autoridad_id) THEN
    RAISE EXCEPTION 'Solo administradores o la entidad responsable pueden actualizar estados';
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
-- 6. RPC: vincular un perfil como funcionario de una entidad (solo admin)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.asignar_funcionario(
  p_profile_id   UUID,
  p_autoridad_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo administradores pueden asignar funcionarios';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.autoridades WHERE id = p_autoridad_id) THEN
    RAISE EXCEPTION 'Autoridad inexistente';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.perfiles WHERE id = p_profile_id) THEN
    RAISE EXCEPTION 'Perfil inexistente';
  END IF;

  UPDATE public.perfiles
  SET role = 'funcionario', autoridad_id = p_autoridad_id
  WHERE id = p_profile_id;
END;
$$;