-- =============================================================================
-- Notificaciones en el ciclo de vida de una denuncia
--
-- 1. Al crear una denuncia se genera una notificación con su estado.
-- 2. Cada cambio de estado genera una notificación (vía trigger, para que
--    aplique a cualquier camino, no solo a la RPC admin).
-- 3. La RPC update_complaint_status deja de insertar la notificación para
--    evitar duplicados; sigue insertando el histórico (que guarda la nota).
-- =============================================================================

-- Etiquetas legibles en español para cada estado.
CREATE OR REPLACE FUNCTION public.complaint_status_label(p_status TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT COALESCE(
    (
      SELECT v.label
      FROM (
        VALUES
          ('recibida',       'Recibida'),
          ('en_revision',    'En revisión'),
          ('en_proceso',     'En proceso'),
          ('resuelta',       'Resuelta'),
          ('rechazada',      'Rechazada'),
          ('archivada',      'Archivada')
      ) AS v(status, label)
      WHERE v.status = p_status
    ),
    p_status
  );
$$;

-- Notificación al crear la denuncia, con su estado inicial.
CREATE OR REPLACE FUNCTION public.notify_complaint_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, complaint_id, title, body)
  VALUES (
    NEW.user_id,
    NEW.id,
    'Denuncia registrada',
    'Tu denuncia "' || NEW.title || '" quedó registrada con estado: '
      || public.complaint_status_label(NEW.status) || '.'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_complaint_created ON public.complaints;
CREATE TRIGGER on_complaint_created
AFTER INSERT ON public.complaints
FOR EACH ROW
EXECUTE FUNCTION public.notify_complaint_created();

-- Notificación en cada cambio de estado (cualquier vía de actualización).
CREATE OR REPLACE FUNCTION public.notify_complaint_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, complaint_id, title, body)
  VALUES (
    NEW.user_id,
    NEW.id,
    'Tu denuncia cambió de estado',
    'Tu denuncia "' || NEW.title || '" ahora está en: '
      || public.complaint_status_label(NEW.status) || '.'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_complaint_status_notify ON public.complaints;
CREATE TRIGGER on_complaint_status_notify
AFTER UPDATE ON public.complaints
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.notify_complaint_status_change();

-- La RPC ya no crea la notificación (la genera el trigger); conserva el histórico.
CREATE OR REPLACE FUNCTION public.update_complaint_status(
  p_complaint_id UUID,
  p_new_status   TEXT,
  p_note         TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_old_status TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo administradores pueden actualizar estados';
  END IF;

  IF p_new_status NOT IN ('recibida', 'en_revision', 'en_proceso', 'resuelta', 'rechazada', 'archivada') THEN
    RAISE EXCEPTION 'Estado de denuncia inválido';
  END IF;

  SELECT status INTO v_old_status
  FROM public.complaints
  WHERE id = p_complaint_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Denuncia no encontrada';
  END IF;

  IF v_old_status = p_new_status THEN
    RETURN;
  END IF;

  UPDATE public.complaints
  SET status = p_new_status
  WHERE id = p_complaint_id;

  INSERT INTO public.complaint_status_history (complaint_id, status, note, created_by)
  VALUES (p_complaint_id, p_new_status, p_note, auth.uid());
END;
$$;

-- Índice para la lista de notificaciones (orden por fecha para un usuario).
CREATE INDEX IF NOT EXISTS notifications_user_created_idx
  ON public.notifications (user_id, created_at DESC);
