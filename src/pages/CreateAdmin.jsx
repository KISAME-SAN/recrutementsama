import { useState } from 'react';
import { createClient } from '@supabase/supabase-js';

// Configuration Supabase avec la clé service
const supabase = createClient(
  "https://dgyadodbiembmclrmqyy.supabase.co",
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRneWFkb2RiaWVtYm1jbHJtcXl5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczMzIzMTQ2MiwiZXhwIjoyMDQ4ODA3NDYyfQ.pp5l57UcJKg-XHb_yhU5Db7OVMqruGbJAMDGAZdMyLI"
);

const CreateAdmin = () => {
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    fullName: '',
    phone: ''
  });

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  const createAdmin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMessage('');

    try {
      // 1. Créer l'utilisateur avec les droits admin
      const { data: { user }, error: userError } = await supabase.auth.admin.createUser({
        email: formData.email,
        password: formData.password,
        email_confirm: true,
        user_metadata: {
          full_name: formData.fullName,
          is_admin: true
        }
      });

      if (userError) throw userError;
      if (!user) throw new Error("Échec de la création de l'utilisateur");

      // 2. Créer le profil admin
      const { error: profileError } = await supabase
        .from('profiles')
        .upsert({
          id: user.id,
          full_name: formData.fullName,
          is_admin: true
        });

      if (profileError) throw profileError;

      // 3. Mettre à jour le rôle dans la table users
      const { error: userRoleError } = await supabase
        .from('users')
        .upsert({
          id: user.id,
          role: 'admin'
        });

      if (userRoleError) throw userRoleError;

      // 4. Mettre à jour les métadonnées de l'utilisateur
      const { error: metadataError } = await supabase.auth.admin
        .updateUserById(user.id, {
          app_metadata: { role: 'admin' }
        });

      if (metadataError) throw metadataError;

      setMessage('Créé avec succès');
      setFormData({ email: '', password: '', fullName: '', phone: '' });
    } catch (error) {
      setMessage('Erreur: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-md mx-auto mt-10 p-6 bg-white rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold mb-6 text-center">Créer un Administrateur</h2>
      
      {message && (
        <div className={`p-4 mb-4 rounded ${message.includes('Erreur') ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}`}>
          {message}
        </div>
      )}

      <form onSubmit={createAdmin} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">Nom complet</label>
          <input
            type="text"
            name="fullName"
            value={formData.fullName}
            onChange={handleChange}
            required
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">Email</label>
          <input
            type="email"
            name="email"
            value={formData.email}
            onChange={handleChange}
            required
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">Téléphone</label>
          <input
            type="tel"
            name="phone"
            value={formData.phone}
            onChange={handleChange}
            required
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">Mot de passe</label>
          <input
            type="password"
            name="password"
            value={formData.password}
            onChange={handleChange}
            required
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
        >
          {loading ? 'Création en cours...' : 'Créer'}
        </button>
      </form>
    </div>
  );
};

export default CreateAdmin;
