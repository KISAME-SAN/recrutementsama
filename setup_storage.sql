-- Création d'un bucket pour stocker les documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'documents',
    'documents',
    false,
    5242880, -- 5MB limite
    ARRAY[
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ]
);

-- Politique pour permettre aux utilisateurs d'uploader leurs documents
CREATE POLICY "Les utilisateurs peuvent uploader leurs documents"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Politique pour permettre aux utilisateurs de voir leurs documents
CREATE POLICY "Les utilisateurs peuvent voir leurs documents"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'documents' AND (
      auth.uid()::text = (storage.foldername(name))[1] OR
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.is_admin = TRUE
      )
    )
  );

-- Politique pour permettre aux utilisateurs de supprimer leurs documents
CREATE POLICY "Les utilisateurs peuvent supprimer leurs documents"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'documents' AND (
      auth.uid()::text = (storage.foldername(name))[1] OR
      EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.is_admin = TRUE
      )
    )
  );
