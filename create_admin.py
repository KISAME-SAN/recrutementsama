from supabase import create_client, Client
import os
import json

# Charger les variables d'environnement
load_dotenv()

# Configuration Supabase
SUPABASE_URL = "https://dgyadodbiembmclrmqyy.supabase.co"
# Utiliser la clé service depuis les variables d'environnement
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_KEY:
    raise ValueError("La clé service Supabase n'est pas définie dans les variables d'environnement")

# Initialisation du client Supabase avec la clé service
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def create_admin_user(email: str, password: str, full_name: str, phone: str):
    try:
        # 1. Créer l'utilisateur avec les droits admin
        user_response = supabase.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {
                "full_name": full_name,
                "is_admin": True
            }
        })

        if not user_response.user:
            raise Exception("Échec de la création de l'utilisateur")

        user_id = user_response.user.id

        # 2. Créer le profil admin
        profile_data = {
            "id": user_id,
            "full_name": full_name,
            "is_admin": True
        }
        supabase.from_('profiles').upsert(profile_data).execute()

        # 3. Mettre à jour le rôle dans la table users
        user_data = {
            "id": user_id,
            "role": "admin"
        }
        supabase.from_('users').upsert(user_data).execute()

        # 4. Ajouter aux hr_managers
        hr_manager_data = {
            "user_id": user_id,
            "full_name": full_name,
            "first_name": full_name.split()[0],
            "phone": phone,
            "email": email,
            "is_active": True
        }
        supabase.from_('hr_managers').upsert(hr_manager_data).execute()

        # 5. Mettre à jour les métadonnées de l'utilisateur
        supabase.auth.admin.update_user_by_id(
            user_id,
            {"app_metadata": {"role": "admin"}}
        )

        print(f"Administrateur créé avec succès: {email}")
        print(f"User ID: {user_id}")
        return user_id

    except Exception as e:
        print(f"Erreur lors de la création de l'administrateur: {str(e)}")
        return None

if __name__ == "__main__":
    admin_email = os.getenv("ADMIN_EMAIL") or "admin@example.com"  # Changez ceci
    admin_password = os.getenv("ADMIN_PASSWORD") or "admin123"        # Changez ceci
    admin_full_name = os.getenv("ADMIN_FULL_NAME") or "Admin User"     # Changez ceci
    admin_phone = os.getenv("ADMIN_PHONE") or "+221000000000"      # Changez ceci
    
    create_admin_user(admin_email, admin_password, admin_full_name, admin_phone)
