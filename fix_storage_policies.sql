-- Activer les extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Supprimer les anciennes politiques si elles existent
DROP POLICY IF EXISTS "Users can upload their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view all documents" ON storage.objects;

-- Politique pour permettre aux utilisateurs d'uploader leurs documents
CREATE POLICY "Users can upload their own documents" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'documents' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Politique pour permettre aux utilisateurs de voir leurs documents
CREATE POLICY "Users can view their own documents" ON storage.objects
FOR SELECT TO authenticated
USING (
    bucket_id = 'documents' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Politique pour permettre aux admins de voir tous les documents
CREATE POLICY "Admins can view all documents" ON storage.objects
FOR SELECT TO authenticated
USING (
    bucket_id = 'documents' AND
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'isAdmin' = 'true'
    )
);

-- Activer RLS sur la table objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
