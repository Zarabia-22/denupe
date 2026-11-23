-- Guarda la ruta/categoría territorial elegida manualmente por el ciudadano.
-- No representa una institución pública concreta ni reemplaza entidad_publica_id.
ALTER TABLE public.denuncias
  ADD COLUMN IF NOT EXISTS ruta_territorial_code TEXT;

COMMENT ON COLUMN public.denuncias.ruta_territorial_code IS
  'Código de la ruta territorial seleccionada manualmente desde el catálogo distrital (alumbrado, seguridad, limpieza, agua, transito, areas_verdes, infraestructura u otros).';
