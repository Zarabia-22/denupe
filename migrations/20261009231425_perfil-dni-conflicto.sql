-- =============================================================================
-- DenuPe: mensaje amigable cuando el DNI ya está registrado por otro usuario
-- (reemplaza la migración 20261009230805_perfil-usuario.sql, conservando su
--  API exacta: actualizar_perfil(full_name, dni, phone, district)).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.actualizar_perfil(
  p_full_name TEXT,
  p_dni       TEXT DEFAULT NULL,
  p_phone     TEXT DEFAULT NULL,
  p_district  TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión';
  END IF;

  IF p_full_name IS NULL OR btrim(p_full_name) = '' THEN
    RAISE EXCEPTION 'El nombre completo es obligatorio';
  END IF;

  BEGIN
    UPDATE public.perfiles
    SET full_name = btrim(p_full_name),
        dni       = NULLIF(btrim(COALESCE(p_dni, '')), ''),
        phone     = NULLIF(btrim(COALESCE(p_phone, '')), ''),
        district  = NULLIF(btrim(COALESCE(p_district, '')), '')
    WHERE id = auth.uid();
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'El DNI ingresado ya está registrado por otro usuario';
  END;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.actualizar_perfil(TEXT, TEXT, TEXT, TEXT)
  TO authenticated, anon;