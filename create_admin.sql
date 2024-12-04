-- Création du compte admin dans auth.users
DO $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Vérifier si l'utilisateur existe déjà
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'admin@example.com';
    
    IF v_user_id IS NULL THEN
        -- Créer le nouvel utilisateur
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            email_change,
            email_change_token_new,
            recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            uuid_generate_v4(),
            'authenticated',
            'authenticated',
            'admin@example.com',
            crypt('admin123', gen_salt('bf')),
            NOW(),
            jsonb_build_object('provider', 'email', 'providers', ARRAY['email'], 'is_admin', true),
            jsonb_build_object('full_name', 'Admin'),
            NOW(),
            NOW(),
            '',
            '',
            '',
            ''
        ) RETURNING id INTO v_user_id;
    END IF;

    -- Créer ou mettre à jour le profil
    INSERT INTO profiles (id, full_name, is_admin)
    VALUES (v_user_id, 'Admin', TRUE)
    ON CONFLICT (id) DO UPDATE
    SET is_admin = TRUE;

    -- Créer ou mettre à jour l'entrée users
    INSERT INTO users (id, role)
    VALUES (v_user_id, 'admin')
    ON CONFLICT (id) DO UPDATE
    SET role = 'admin';

    -- Créer ou mettre à jour l'entrée hr_managers
    INSERT INTO hr_managers (user_id, full_name, first_name, phone, email)
    VALUES (v_user_id, 'Admin', 'Admin', '+221000000000', 'admin@example.com')
    ON CONFLICT DO NOTHING;

END $$;
