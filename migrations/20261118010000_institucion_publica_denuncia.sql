-- =============================================================================
-- DenuPe · Institución pública específica seleccionada por el ciudadano
-- =============================================================================
-- La autoridad interna se conserva para el flujo de funcionarios existente.
-- Estos campos guardan además el identificador y nombre exactos del organismo
-- devuelto por el catálogo de HU-IA-02.
ALTER TABLE public.denuncias
  ADD COLUMN IF NOT EXISTS entidad_publica_id TEXT,
  ADD COLUMN IF NOT EXISTS entidad_publica_nombre TEXT;

COMMENT ON COLUMN public.denuncias.entidad_publica_id IS
  'Identificador estable del organismo en el catálogo de instituciones públicas (por ejemplo mun-150103 o pnp-<código>).';
COMMENT ON COLUMN public.denuncias.entidad_publica_nombre IS
  'Nombre exacto de la institución pública seleccionada por el ciudadano.';

-- Las instituciones especializadas se agrupan bajo este receptor interno
-- hasta incorporar un flujo de funcionarios por institución específica.
INSERT INTO public.autoridades (nombre, sigla, tipo, descripcion)
VALUES (
  'Entidad pública especializada',
  'ESP',
  'otro',
  'Receptor interno para instituciones públicas especializadas identificadas en el catálogo de competencias.'
)
ON CONFLICT (nombre) DO NOTHING;
