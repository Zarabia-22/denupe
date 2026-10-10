-- =============================================================================
-- DenuPe: solo los ciudadanos (y admins) pueden registrar denuncias
-- -----------------------------------------------------------------------------
-- El rol `funcionario` gestiona las denuncias de su entidad pero no crea
-- nuevas. La política de INSERT sobre denuncias pasa a exigir rol citizen
-- (o admin), además de ser la propia denuncia del solicitante.
-- =============================================================================

-- Helper: el usuario autenticado es un ciudadano.
CREATE OR REPLACE FUNCTION public.is_citizen()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles
    WHERE id = auth.uid() AND role = 'citizen'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_citizen() TO authenticated, anon;

DROP POLICY IF EXISTS complaints_insert_own_or_admin ON public.denuncias;

CREATE POLICY denuncias_insert_ciudadano_o_admin
ON public.denuncias FOR INSERT TO authenticated
WITH CHECK (
  (user_id = (SELECT auth.uid()) AND public.is_citizen())
  OR public.is_admin()
);