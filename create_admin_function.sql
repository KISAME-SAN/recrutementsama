-- Fonction pour créer un administrateur
create or replace function create_admin_user(
  email text,
  password text,
  full_name text,
  phone text
)
returns json
language plpgsql
security definer -- Permet d'ignorer RLS
set search_path = public
as $$
declare
  new_user_id uuid;
  result json;
begin
  -- 1. Créer l'utilisateur dans auth.users
  insert into auth.users (email, encrypted_password, email_confirmed_at, raw_user_meta_data)
  values (
    email,
    crypt(password, gen_salt('bf')),
    now(),
    jsonb_build_object(
      'full_name', full_name,
      'is_admin', true
    )
  )
  returning id into new_user_id;

  -- 2. Créer le profil dans profiles
  insert into public.profiles (id, full_name, is_admin)
  values (new_user_id, full_name, true);

  -- 3. Mettre à jour le rôle dans users
  insert into public.users (id, role)
  values (new_user_id, 'admin');

  -- 4. Mettre à jour les métadonnées de l'utilisateur
  update auth.users
  set raw_app_meta_data = jsonb_build_object('role', 'admin')
  where id = new_user_id;

  -- Retourner les informations de l'utilisateur créé
  select json_build_object(
    'user_id', new_user_id,
    'email', email,
    'full_name', full_name,
    'role', 'admin'
  ) into result;

  return result;
exception
  when others then
    raise exception 'Erreur lors de la création de l''administrateur: %', SQLERRM;
end;
$$;
