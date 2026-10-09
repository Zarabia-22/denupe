-- =============================================================================
-- DenuPe: edición del perfil del usuario
-- -----------------------------------------------------------------------------
-- El rol `authenticated` solo tiene SELECT sobre public.perfiles, por lo que la
-- edición se expone mediante un RPC acotado que:
--   * solo modifica la fila del propio usuario (auth.uid()),
--   * solo toca columnas editables (full_name, dni, phone, district),
--   * nunca permite cambiar role ni autoridad_id.
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

  UPDATE public.perfiles
  SET full_name = btrim(p_full_name),
      dni       = NULLIF(btrim(COALESCE(p_dni, '')), ''),
      phone     = NULLIF(btrim(COALESCE(p_phone, '')), ''),
      district  = NULLIF(btrim(COALESCE(p_district, '')), '')
  WHERE id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.actualizar_perfil(TEXT, TEXT, TEXT, TEXT)
  TO authenticated, anon;