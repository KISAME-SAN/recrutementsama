-- Réinitialiser les politiques de stockage
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated downloads" ON storage.objects;

-- Permettre l'upload pour les utilisateurs authentifiés
CREATE POLICY "Allow authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents');

-- Permettre le téléchargement pour les utilisateurs authentifiés
CREATE POLICY "Allow authenticated downloads"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'documents');

-- S'assurer que RLS est activé
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
