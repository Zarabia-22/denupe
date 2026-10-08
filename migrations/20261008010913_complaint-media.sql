-- =============================================================================
-- DenuPe: adjuntos multimedia de denuncias (imágenes y videos)
-- -----------------------------------------------------------------------------
-- 1. Tabla complaint_media        (cada archivo adjunto de una denuncia)
-- 2. Bucket complaint-media       (privado; se crea vía CLI, documento en README)
-- 3. RLS sobre complaint_media    (dueño de la denuncia o admin)
-- 4. RLS sobre storage.objects    (solo dueño sube/ve/borra; admin lee todo)
-- =============================================================================

-- =============================================================================
-- 1. complaint_media
-- =============================================================================
CREATE TABLE public.complaint_media (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id UUID NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  storage_key  TEXT NOT NULL,
  url          TEXT NOT NULL,
  media_type   TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
  mime_type    TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.complaint_media ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 2. Grants
-- =============================================================================
GRANT SELECT, INSERT, DELETE ON public.complaint_media TO authenticated;
REVOKE UPDATE ON public.complaint_media FROM authenticated;

-- =============================================================================
-- 3. RLS sobre complaint_media
--    - Lectura: dueño de la denuncia o admin.
--    - Inserción: el usuario autenticado y dueño de la denuncia (o admin).
--    - Borrado: dueño de la denuncia o admin.
-- =============================================================================
CREATE POLICY complaint_media_select_own_or_admin
ON public.complaint_media FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.complaints c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid()) OR public.is_admin())
  )
);

CREATE POLICY complaint_media_insert_own_or_admin
ON public.complaint_media FOR INSERT TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.complaints c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid()) OR public.is_admin())
  )
);

CREATE POLICY complaint_media_delete_own_or_admin
ON public.complaint_media FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.complaints c
    WHERE c.id = complaint_id
      AND (c.user_id = (SELECT auth.uid()) OR public.is_admin())
  )
);

CREATE INDEX complaint_media_complaint_id_idx ON public.complaint_media (complaint_id);

-- =============================================================================
-- 4. RLS sobre storage.objects (bucket "complaint-media", privado)
--    El objeto solo es visible/borrable por quien lo subió (auth sub);
--    los administradores pueden leer cualquier adjunto.
-- =============================================================================
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS complaint_media_objects_select ON storage.objects;
CREATE POLICY complaint_media_objects_select ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket = 'complaint-media'
  AND (
    uploaded_by = (SELECT auth.jwt() ->> 'sub')
    OR public.is_admin()
  )
);

DROP POLICY IF EXISTS complaint_media_objects_insert ON storage.objects;
CREATE POLICY complaint_media_objects_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket = 'complaint-media'
  AND uploaded_by = (SELECT auth.jwt() ->> 'sub')
);

DROP POLICY IF EXISTS complaint_media_objects_update ON storage.objects;
CREATE POLICY complaint_media_objects_update ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket = 'complaint-media'
  AND uploaded_by = (SELECT auth.jwt() ->> 'sub')
)
WITH CHECK (
  bucket = 'complaint-media'
  AND uploaded_by = (SELECT auth.jwt() ->> 'sub')
);

DROP POLICY IF EXISTS complaint_media_objects_delete ON storage.objects;
CREATE POLICY complaint_media_objects_delete ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket = 'complaint-media'
  AND uploaded_by = (SELECT auth.jwt() ->> 'sub')
);

GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;