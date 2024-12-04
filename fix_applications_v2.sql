-- 1. Supprimer toutes les politiques existantes
DROP POLICY IF EXISTS "insert_application" ON applications;
DROP POLICY IF EXISTS "view_own_applications" ON applications;
DROP POLICY IF EXISTS "update_as_admin" ON applications;
DROP POLICY IF EXISTS "Les utilisateurs peuvent voir leurs propres candidatures" ON applications;
DROP POLICY IF EXISTS "Les utilisateurs peuvent créer leurs propres candidatures" ON applications;
DROP POLICY IF EXISTS "Les admins peuvent tout faire avec les candidatures" ON applications;
DROP POLICY IF EXISTS "allow_select" ON applications;
DROP POLICY IF EXISTS "allow_insert" ON applications;
DROP POLICY IF EXISTS "allow_update" ON applications;
DROP POLICY IF EXISTS "allow_delete" ON applications;
DROP POLICY IF EXISTS "allow_patch" ON applications;

-- 2. S'assurer que RLS est activé
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

-- 3. Créer une politique simple pour l'insertion
CREATE POLICY "enable_insert_for_authenticated" ON applications
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- 4. Créer une politique pour la lecture
CREATE POLICY "enable_select_for_users_and_admins" ON applications
    FOR SELECT TO authenticated
    USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.is_admin = true
        )
    );

-- 5. Créer une politique pour la mise à jour
CREATE POLICY "enable_update_for_admins" ON applications
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.is_admin = true
        )
    );

-- 6. Accorder les permissions de base
GRANT ALL ON applications TO authenticated;

-- 7. Créer une fonction de debug pour les insertions
CREATE OR REPLACE FUNCTION debug_application_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Log l'insertion
    RAISE NOTICE 'Tentative d''insertion d''une candidature: user_id=%, job_id=%', NEW.user_id, NEW.job_id;
    
    -- Vérifier l'authentification
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Utilisateur non authentifié';
    END IF;
    
    -- Log l'utilisateur authentifié
    RAISE NOTICE 'Utilisateur authentifié: auth.uid()=%', auth.uid();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Créer le trigger de debug
DROP TRIGGER IF EXISTS tr_debug_application_insert ON applications;
CREATE TRIGGER tr_debug_application_insert
    BEFORE INSERT ON applications
    FOR EACH ROW
    EXECUTE FUNCTION debug_application_insert();

-- 9. Vérifier la structure de la table
DO $$ 
BEGIN
    -- Vérifier les contraintes
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE table_name = 'applications' 
        AND constraint_name = 'applications_user_id_fkey'
    ) THEN
        RAISE NOTICE 'Contrainte de clé étrangère manquante sur user_id';
    END IF;
    
    -- Vérifier les index
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_indexes 
        WHERE tablename = 'applications' 
        AND indexname = 'idx_applications_user_id'
    ) THEN
        CREATE INDEX idx_applications_user_id ON applications(user_id);
    END IF;
END $$;
