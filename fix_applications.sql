-- 1. Vérifier et corriger la table applications
DO $$ 
BEGIN
    -- Vérifier si la table existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'applications') THEN
        CREATE TABLE applications (
            id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
            user_id UUID REFERENCES auth.users(id) NOT NULL,
            job_id UUID REFERENCES jobs(id) NOT NULL,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            email TEXT NOT NULL,
            phone TEXT NOT NULL,
            gender TEXT NOT NULL,
            age INTEGER NOT NULL,
            professional_experience TEXT NOT NULL,
            skills TEXT NOT NULL,
            diploma TEXT NOT NULL,
            years_of_experience INTEGER NOT NULL,
            previous_company TEXT,
            cv_url TEXT NOT NULL,
            cover_letter_url TEXT NOT NULL,
            status TEXT DEFAULT 'en attente',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );
    END IF;
END $$;

-- 2. Supprimer toutes les anciennes politiques
DROP POLICY IF EXISTS "allow_select" ON applications;
DROP POLICY IF EXISTS "allow_insert" ON applications;
DROP POLICY IF EXISTS "allow_update" ON applications;
DROP POLICY IF EXISTS "allow_delete" ON applications;
DROP POLICY IF EXISTS "allow_patch" ON applications;
DROP POLICY IF EXISTS "Utilisateurs peuvent créer leurs candidatures" ON applications;
DROP POLICY IF EXISTS "Utilisateurs peuvent voir leurs candidatures" ON applications;
DROP POLICY IF EXISTS "Admins peuvent mettre à jour les candidatures" ON applications;

-- 3. Activer RLS
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

-- 4. Créer les nouvelles politiques
CREATE POLICY "applications_insert_policy" ON applications 
    FOR INSERT TO authenticated 
    WITH CHECK (true);

CREATE POLICY "applications_select_policy" ON applications 
    FOR SELECT TO authenticated 
    USING (
        auth.uid() = user_id 
        OR 
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.is_admin = true
        )
    );

CREATE POLICY "applications_update_policy" ON applications 
    FOR UPDATE TO authenticated 
    USING (
        auth.uid() = user_id 
        OR 
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.is_admin = true
        )
    );

-- 5. Créer le trigger pour la mise à jour du timestamp
CREATE OR REPLACE FUNCTION update_application_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_application_timestamp ON applications;
CREATE TRIGGER update_application_timestamp
    BEFORE UPDATE ON applications
    FOR EACH ROW
    EXECUTE FUNCTION update_application_timestamp();

-- 6. Créer le trigger pour les notifications
CREATE OR REPLACE FUNCTION notify_application_submission()
RETURNS TRIGGER AS $$
DECLARE
    admin_record RECORD;
BEGIN
    -- Créer une notification pour chaque admin
    FOR admin_record IN 
        SELECT id 
        FROM profiles 
        WHERE is_admin = TRUE
    LOOP
        INSERT INTO notifications (
            message,
            admin_id,
            user_id,
            application_id,
            status,
            is_read,
            notification_type
        ) VALUES (
            'Nouvelle candidature reçue de ' || NEW.first_name || ' ' || NEW.last_name,
            admin_record.id,
            NEW.user_id,
            NEW.id,
            'non lu',
            false,
            'application'
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS notify_on_application ON applications;
CREATE TRIGGER notify_on_application
    AFTER INSERT ON applications
    FOR EACH ROW
    EXECUTE FUNCTION notify_application_submission();

-- 7. Donner les permissions nécessaires
GRANT ALL ON applications TO authenticated;

-- 8. Créer les index nécessaires
CREATE INDEX IF NOT EXISTS idx_applications_user_id ON applications(user_id);
CREATE INDEX IF NOT EXISTS idx_applications_job_id ON applications(job_id);
CREATE INDEX IF NOT EXISTS idx_applications_status ON applications(status);
CREATE INDEX IF NOT EXISTS idx_applications_created_at ON applications(created_at DESC);
