-- Permite que operaciones de administración (auth.uid() NULL, p.ej. CLI/SDK admin)
-- modifiquen rol/estado sin pasar por la regla de "solo admin con sesión".

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
  IF (NEW.status IS DISTINCT FROM OLD.status OR NEW.priority IS DISTINCT FROM OLD.priority OR NEW.user_id IS DISTINCT FROM OLD.user_id)
     AND (SELECT auth.uid()) IS NOT NULL
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tienes permisos para modificar este campo';
  END IF;
  RETURN NEW;
END;
$$;