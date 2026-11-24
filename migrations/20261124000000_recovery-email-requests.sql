CREATE TABLE IF NOT EXISTS public.solicitudes_recuperacion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'solicitado' CHECK (status IN ('solicitado', 'completado', 'expirado'))
);

ALTER TABLE public.solicitudes_recuperacion ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.solicitudes_recuperacion FROM anon, authenticated;

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT INSERT (email) ON public.solicitudes_recuperacion TO anon, authenticated;

CREATE POLICY anon_insert_recovery_requests
  ON public.solicitudes_recuperacion
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_solicitudes_recuperacion_created_at
  ON public.solicitudes_recuperacion (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_solicitudes_recuperacion_email
  ON public.solicitudes_recuperacion (lower(email));
