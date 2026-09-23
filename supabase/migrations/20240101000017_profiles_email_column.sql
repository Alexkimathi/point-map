-- Migration 017: Add email column to profiles
-- The app's createUserAction upserts email into profiles,
-- but the column was missing from the original schema.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Back-fill existing rows from auth.users
UPDATE profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id AND p.email IS NULL;

-- Update the handle_new_user trigger to also store email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'surveyor')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
