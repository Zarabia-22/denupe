-- =============================================================================
-- DenuPe · Asignación segura cuando no existe una institución única validada
-- =============================================================================
INSERT INTO public.autoridades (nombre, sigla, tipo, descripcion)
VALUES (
  'Revisión de competencia',
  'REV',
  'otro',
  'Bandeja interna para denuncias cuya institución competente requiere validación humana. Evita asignaciones automáticas a organismos no verificados.'
)
ON CONFLICT (nombre) DO NOTHING;

-- Ninguna categoría debe enviarse por defecto a una institución que no haya
-- sido validada para el incidente concreto. La selección manual o HU-IA-02
-- puede establecer la institución específica; en ausencia de una opción
-- única, la denuncia queda en revisión de competencia.
UPDATE public.categorias
SET autoridad_predeterminada_id = (
  SELECT id FROM public.autoridades WHERE sigla = 'REV'
)
WHERE autoridad_predeterminada_id IS DISTINCT FROM (
  SELECT id FROM public.autoridades WHERE sigla = 'REV'
);
