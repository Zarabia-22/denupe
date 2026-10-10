-- =============================================================================
-- DenuPe: datos del denunciante en la denuncia
-- -----------------------------------------------------------------------------
-- Al registrar una denuncia se guarda una copia (snapshot) del nombre, DNI,
-- correo y teléfono del ciudadano tomados de su perfil. Así la entidad
-- responsable puede contactarlo, ya que la RLS de perfiles no le permite leer
-- el perfil de terceros.
-- =============================================================================

ALTER TABLE public.denuncias
  ADD COLUMN denunciante_nombre   TEXT,
  ADD COLUMN denunciante_dni      TEXT,
  ADD COLUMN denunciante_email    TEXT,
  ADD COLUMN denunciante_telefono TEXT;

CREATE OR REPLACE FUNCTION public.asignar_datos_denunciante()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_nombre TEXT;
  v_dni    TEXT;
  v_phone  TEXT;
  v_email  TEXT;
BEGIN
  SELECT p.full_name, p.dni, p.phone, u.email
    INTO v_nombre, v_dni, v_phone, v_email
  FROM public.perfiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE p.id = NEW.user_id;

  NEW.denunciante_nombre   := COALESCE(NEW.denunciante_nombre, v_nombre);
  NEW.denunciante_dni      := COALESCE(NEW.denunciante_dni, v_dni);
  NEW.denunciante_telefono := COALESCE(NEW.denunciante_telefono, v_phone);
  NEW.denunciante_email    := COALESCE(NEW.denunciante_email, v_email);

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_denuncia_datos_denunciante
BEFORE INSERT ON public.denuncias
FOR EACH ROW
EXECUTE FUNCTION public.asignar_datos_denunciante();