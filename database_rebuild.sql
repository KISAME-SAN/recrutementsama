-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create profiles table
CREATE TABLE profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE,
  full_name TEXT,
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  PRIMARY KEY (id)
);

-- Create users table for roles
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin', 'hr')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create HR managers table
CREATE TABLE hr_managers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    first_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create jobs table
CREATE TABLE jobs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  positions INTEGER NOT NULL,
  location TEXT NOT NULL,
  contract_type TEXT NOT NULL,
  department TEXT NOT NULL,
  expiration_date DATE NOT NULL,
  diploma TEXT NOT NULL,
  description TEXT NOT NULL,
  technical_skills TEXT NOT NULL,
  soft_skills TEXT NOT NULL,
  tools TEXT NOT NULL,
  experience TEXT NOT NULL,
  french_level TEXT NOT NULL,
  english_level TEXT NOT NULL,
  wolof_level TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  created_by UUID REFERENCES profiles(id),
  is_active BOOLEAN DEFAULT TRUE
);

-- Create applications table
CREATE TABLE applications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    job_id UUID REFERENCES jobs(id),
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

-- Create notifications table
CREATE TABLE notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    message TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    admin_id UUID REFERENCES auth.users(id),
    application_id UUID REFERENCES applications(id),
    status TEXT DEFAULT 'en attente',
    is_read BOOLEAN DEFAULT false,
    notification_type TEXT NOT NULL DEFAULT 'application',
    action_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    read_at TIMESTAMPTZ
);

-- Create indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_admin_id ON notifications(admin_id);
CREATE INDEX idx_notifications_application_id ON notifications(application_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_read_at ON notifications(read_at) WHERE read_at IS NOT NULL;
CREATE INDEX idx_applications_user_id ON applications(user_id);
CREATE INDEX idx_applications_status ON applications(status);

-- Create functions
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, is_admin)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', FALSE);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION update_notification_read_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_read = true AND OLD.is_read = false THEN
        NEW.read_at = NOW();
    ELSIF NEW.is_read = false THEN
        NEW.read_at = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark_notification_as_read(notification_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE notifications
    SET is_read = true,
        read_at = NOW()
    WHERE id = notification_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark_all_notifications_as_read(user_uuid UUID, is_admin BOOLEAN)
RETURNS VOID AS $$
BEGIN
    IF is_admin THEN
        UPDATE notifications
        SET is_read = true,
            read_at = NOW()
        WHERE admin_id = user_uuid AND is_read = false;
    ELSE
        UPDATE notifications
        SET is_read = true,
            read_at = NOW()
        WHERE user_id = user_uuid AND is_read = false;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_unread_notifications_count(user_uuid UUID, is_admin BOOLEAN)
RETURNS INTEGER AS $$
DECLARE
    count INTEGER;
BEGIN
    IF is_admin THEN
        SELECT COUNT(*)
        INTO count
        FROM notifications
        WHERE admin_id = user_uuid AND is_read = false;
    ELSE
        SELECT COUNT(*)
        INTO count
        FROM notifications
        WHERE user_id = user_uuid AND is_read = false;
    END IF;
    
    RETURN count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_hr_user(
    p_email TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_first_name TEXT,
    p_phone TEXT
) RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Create auth user
    v_user_id := (SELECT id FROM auth.users WHERE email = p_email);
    IF v_user_id IS NULL THEN
        v_user_id := (
            WITH new_user AS (
                INSERT INTO auth.users (email, password, email_confirmed_at)
                VALUES (p_email, crypt(p_password, gen_salt('bf')), now())
                RETURNING id
            )
            SELECT id FROM new_user
        );
    END IF;

    -- Insert into users table with HR role
    INSERT INTO users (id, role)
    VALUES (v_user_id, 'hr')
    ON CONFLICT (id) DO UPDATE
    SET role = 'hr';

    -- Insert into hr_managers
    INSERT INTO hr_managers (user_id, full_name, first_name, phone, email)
    VALUES (v_user_id, p_full_name, p_first_name, p_phone, p_email);

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE handle_new_user();

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER update_hr_managers_updated_at
    BEFORE UPDATE ON hr_managers
    FOR EACH ROW
    EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER update_notification_read_at
    BEFORE UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_read_status();

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_managers ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Create policies for profiles
CREATE POLICY "Les utilisateurs peuvent voir leur propre profil"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Les utilisateurs peuvent modifier leur propre profil"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- Create policies for users
CREATE POLICY "Users can read their own role" ON users
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Admins can manage all users" ON users
    FOR ALL
    TO authenticated
    USING (EXISTS (
        SELECT 1 FROM users AS u
        WHERE u.id = auth.uid() AND u.role = 'admin'
    ));

-- Create policies for HR managers
CREATE POLICY "Admin can read all HR records" ON hr_managers
    FOR SELECT
    TO authenticated
    USING (EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid() AND users.role = 'admin'
    ));

CREATE POLICY "Admin can create HR records" ON hr_managers
    FOR INSERT
    TO authenticated
    WITH CHECK (EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid() AND users.role = 'admin'
    ));

CREATE POLICY "Admin can update HR records" ON hr_managers
    FOR UPDATE
    TO authenticated
    USING (EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid() AND users.role = 'admin'
    ));

CREATE POLICY "Admin can delete HR records" ON hr_managers
    FOR DELETE
    TO authenticated
    USING (EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid() AND users.role = 'admin'
    ));

-- Create policies for jobs
CREATE POLICY "Tout le monde peut voir les offres actives"
    ON jobs FOR SELECT
    USING (is_active = TRUE);

CREATE POLICY "Les admins peuvent tout faire avec les offres"
    ON jobs FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.is_admin = TRUE
        )
    );

-- Create policies for applications
CREATE POLICY "allow_select" ON applications FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_insert" ON applications FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_update" ON applications FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_delete" ON applications FOR DELETE TO authenticated USING (true);
CREATE POLICY "allow_patch" ON applications FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Create policies for notifications
CREATE POLICY "Users can view their own notifications"
ON notifications FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id OR
    EXISTS (
        SELECT 1 FROM auth.users u
        WHERE u.id = auth.uid()
        AND (u.raw_app_meta_data->>'is_admin' = 'true' OR u.raw_app_meta_data->>'is_hr' = 'true')
    )
);

CREATE POLICY "Users can update their own notifications"
ON notifications FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
);

-- Create views
CREATE OR REPLACE VIEW unread_notifications AS
SELECT *
FROM notifications
WHERE is_read = false;

-- Create application status update function
CREATE OR REPLACE FUNCTION update_application_status(
    app_id UUID,
    new_status TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE applications
    SET status = new_status
    WHERE id = app_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT ALL ON applications TO authenticated;
GRANT EXECUTE ON FUNCTION update_application_status TO authenticated;
