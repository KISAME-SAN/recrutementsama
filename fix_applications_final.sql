-- 1. Nettoyer complètement la table et ses dépendances
DROP TRIGGER IF EXISTS on_new_application ON applications;
DROP TRIGGER IF EXISTS on_application_status_change ON applications;
DROP TRIGGER IF EXISTS update_timestamp ON applications;
DROP FUNCTION IF EXISTS handle_new_application();
DROP FUNCTION IF EXISTS handle_application_status_change();
DROP FUNCTION IF EXISTS update_timestamp();
DROP FUNCTION IF EXISTS update_application_status(UUID, TEXT);

-- 2. Supprimer toutes les politiques existantes
DROP POLICY IF EXISTS "Les utilisateurs peuvent voir leurs propres candidatures" ON applications;
DROP POLICY IF EXISTS "Les utilisateurs peuvent créer leurs propres candidatures" ON applications;
DROP POLICY IF EXISTS "Les admins peuvent tout faire avec les candidatures" ON applications;
DROP POLICY IF EXISTS "allow_select" ON applications;
DROP POLICY IF EXISTS "allow_insert" ON applications;
DROP POLICY IF EXISTS "allow_update" ON applications;
DROP POLICY IF EXISTS "allow_delete" ON applications;
DROP POLICY IF EXISTS "allow_patch" ON applications;

-- 3. Recréer la table applications proprement
DROP TABLE IF EXISTS applications CASCADE;
CREATE TABLE applications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    gender TEXT NOT NULL CHECK (gender IN ('homme', 'femme')),
    age INTEGER NOT NULL CHECK (age >= 18),
    professional_experience TEXT NOT NULL,
    skills TEXT NOT NULL,
    diploma TEXT NOT NULL,
    years_of_experience INTEGER NOT NULL,
    previous_company TEXT,
    cv_url TEXT NOT NULL,
    cover_letter_url TEXT NOT NULL,
    status TEXT DEFAULT 'en attente' CHECK (status IN ('en attente', 'en cours d''examination', 'accepter', 'refuser')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Créer les index nécessaires
CREATE INDEX idx_applications_user_id ON applications(user_id);
CREATE INDEX idx_applications_job_id ON applications(job_id);
CREATE INDEX idx_applications_status ON applications(status);
CREATE INDEX idx_applications_created_at ON applications(created_at DESC);

-- 5. Activer RLS
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

-- 6. Créer les politiques RLS simples et claires
CREATE POLICY "insert_application"
    ON applications FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "view_own_applications"
    ON applications FOR SELECT
    TO authenticated
    USING (
        auth.uid() = user_id
        OR 
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.is_admin = true
        )
    );

CREATE POLICY "update_as_admin"
    ON applications FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.is_admin = true
        )
    );

-- 7. Donner les permissions nécessaires
GRANT ALL ON applications TO authenticated;

-- 8. Créer le trigger de notification
CREATE OR REPLACE FUNCTION notify_new_application()
RETURNS TRIGGER AS $$
DECLARE
    admin_record RECORD;
BEGIN
    FOR admin_record IN 
        SELECT id 
        FROM profiles 
        WHERE is_admin = true
    LOOP
        INSERT INTO notifications (
            message,
            admin_id,
            user_id,
            application_id,
            status,
            is_read
        ) VALUES (
            'Nouvelle candidature reçue de ' || NEW.first_name || ' ' || NEW.last_name,
            admin_record.id,
            NEW.user_id,
            NEW.id,
            'non lu',
            false
        );
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER notify_new_application
    AFTER INSERT ON applications
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_application();

-- 9. Créer le trigger de mise à jour du timestamp
CREATE OR REPLACE FUNCTION update_application_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_application_timestamp
    BEFORE UPDATE ON applications
    FOR EACH ROW
    EXECUTE FUNCTION update_application_timestamp();
