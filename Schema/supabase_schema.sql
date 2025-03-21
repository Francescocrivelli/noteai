-- Create users table
CREATE TABLE public.users (
  id UUID NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMP WITH TIME ZONE,
  reactivated_at TIMESTAMP WITH TIME ZONE
);

-- Create user_preferences table
CREATE TABLE public.user_preferences (
  id UUID NOT NULL DEFAULT EXTENSIONS.UUID_GENERATE_V4() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  has_completed_onboarding BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  CONSTRAINT user_preferences_user_id_key UNIQUE (user_id)
);

-- Create subscriptions table - modified for StoreKit
CREATE TABLE public.subscriptions (
  id UUID NOT NULL DEFAULT GEN_RANDOM_UUID() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  original_transaction_id TEXT,
  latest_transaction_id TEXT,
  status TEXT NOT NULL,
  expiration_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create contacts table
CREATE TABLE public.contacts (
  id UUID NOT NULL DEFAULT GEN_RANDOM_UUID() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  phone_number TEXT,
  email TEXT,
  text_description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create labels table
CREATE TABLE public.labels (
  id UUID NOT NULL DEFAULT GEN_RANDOM_UUID() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_label_name_per_user UNIQUE (user_id, name)
);

-- Create junction table for contacts and labels
CREATE TABLE public.contact_labels (
  id UUID NOT NULL DEFAULT GEN_RANDOM_UUID() PRIMARY KEY,
  contact_id UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  label_id UUID NOT NULL REFERENCES public.labels(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_contact_label_pair UNIQUE (contact_id, label_id)
);

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.labels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_labels ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "Users can read their own data" ON public.users 
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own data" ON public.users 
  FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Service role full access to users" ON public.users 
  FOR ALL TO service_role USING (true);

-- User preferences policies
CREATE POLICY "Users can read their own preferences" ON public.user_preferences 
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own preferences" ON public.user_preferences 
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own preferences" ON public.user_preferences 
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access to preferences" ON public.user_preferences 
  FOR ALL TO service_role USING (true);

-- Subscriptions policies
CREATE POLICY "Users can read their own subscriptions" ON public.subscriptions 
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own subscriptions" ON public.subscriptions 
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own subscriptions" ON public.subscriptions 
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access to subscriptions" ON public.subscriptions 
  FOR ALL TO service_role USING (true);

-- Contacts policies
CREATE POLICY "Users can read their own contacts" ON public.contacts 
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own contacts" ON public.contacts 
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own contacts" ON public.contacts 
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own contacts" ON public.contacts 
  FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Service role full access to contacts" ON public.contacts 
  FOR ALL TO service_role USING (true);

-- Labels policies
CREATE POLICY "Users can read their own labels" ON public.labels 
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own labels" ON public.labels 
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own labels" ON public.labels 
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own labels" ON public.labels 
  FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Service role full access to labels" ON public.labels 
  FOR ALL TO service_role USING (true);

-- Contact_labels policies
CREATE POLICY "Users can read their own contact_labels" ON public.contact_labels 
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.contacts 
      WHERE contacts.id = contact_labels.contact_id AND contacts.user_id = auth.uid()
    )
  );
CREATE POLICY "Users can insert their own contact_labels" ON public.contact_labels 
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.contacts 
      WHERE contacts.id = contact_labels.contact_id AND contacts.user_id = auth.uid()
    )
  );
CREATE POLICY "Users can delete their own contact_labels" ON public.contact_labels 
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.contacts 
      WHERE contacts.id = contact_labels.contact_id AND contacts.user_id = auth.uid()
    )
  );
CREATE POLICY "Service role full access to contact_labels" ON public.contact_labels 
  FOR ALL TO service_role USING (true);
