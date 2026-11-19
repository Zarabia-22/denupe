-- =============================================================================
-- DenuPe · Institución pública específica seleccionada por el ciudadano
-- =============================================================================
-- La autoridad interna sigue siendo necesaria para el flujo de funcionarios
-- actual. Estos campos conservan además el identificador y nombre exactos del
-- organismo público devuelto por el catálogo de HU-IA-02.
ALTER TABLE public.denuncias
  ADD COLUMN IF NOT EXISTS entidad_publica_id TEXT,
  ADD COLUMN IF NOT EXISTS entidad_publica_nombre TEXT;

COMMENT ON COLUMN public.denuncias.entidad_publica_id IS
  'Identificador estable del organismo en el catálogo de instituciones públicas (por ejemplo mun-150103 o pnp-<código>).';
COMMENT ON COLUMN public.denuncias.entidad_publica_nombre IS
  'Nombre exacto de la institución pública seleccionada por el ciudadano.';

-- Las entidades especializadas (ATU, concesionarias eléctricas, etc.) se
-- agrupan bajo este receptor interno hasta que DenuPe incorpore su propio
-- flujo de funcionarios por institución.
INSERT INTO public.autoridades (nombre, sigla, tipo, descripcion)
VALUES (
  'Entidad pública especializada',
  'ESP',
  'otro',
  'Receptor interno para instituciones públicas especializadas identificadas en el catálogo de competencias.'
)
ON CONFLICT (nombre) DO NOTHING;

GRANT SELECT ON public.autoridades TO anon, authenticated;
