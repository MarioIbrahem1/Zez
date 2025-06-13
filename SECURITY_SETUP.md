# 🔐 Security Configuration Setup

## 🚨 IMPORTANT: Credentials Removed for Security
The following files have been removed from the repository to protect sensitive information:
- `lib/config/fcm_v1_config.dart` (contained private keys)
- `assets/service-account-key.json` (service account credentials)

## 📋 Setup Instructions

### 1. FCM v1 Configuration

1. **Copy the template file:**
   ```bash
   cp lib/config/fcm_v1_config.template.dart lib/config/fcm_v1_config.dart
   ```

2. **Get Firebase Service Account Key:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project: `road-helper-fed8f`
   - Go to Project Settings → Service accounts
   - Click "Generate new private key"
   - Download the JSON file

3. **Update the configuration:**
   - Open `lib/config/fcm_v1_config.dart`
   - Replace `YOUR_PROJECT_ID` with: `road-helper-fed8f`
   - Replace the entire `serviceAccount` map with your downloaded JSON content

### 2. Service Account Key File

1. **Place the service account file:**
   ```bash
   # Copy your downloaded service account JSON file to:
   assets/service-account-key.json
   ```

2. **Update Android configuration:**
   - Copy the same file to: `android/app/src/main/assets/service-account-key.json`

## 🛡️ Security Best Practices

### Files that should NEVER be committed:
- `lib/config/fcm_v1_config.dart` (contains private keys)
- `assets/service-account-key.json` (service account credentials)
- `android/app/src/main/assets/service-account-key.json`

### Files that are safe to commit:
- `lib/config/fcm_v1_config.template.dart` (template without real credentials)
- This README file

## 🔧 Quick Setup Commands

```bash
# 1. Copy template
cp lib/config/fcm_v1_config.template.dart lib/config/fcm_v1_config.dart

# 2. Edit the config file with your credentials
# Replace YOUR_PROJECT_ID with: road-helper-fed8f
# Replace serviceAccount map with your Firebase JSON

# 3. Add your service account JSON file
# Place it at: assets/service-account-key.json
```

## 🚨 If Credentials Are Exposed

If you accidentally commit credentials:

1. **Immediately revoke the service account key** in Firebase Console
2. **Generate a new service account key**
3. **Remove the sensitive files from Git history**
4. **Force push to update remote repository**

## 📝 Notes

- The `.gitignore` file is now configured to exclude sensitive Firebase files
- Always regenerate service account keys if they are accidentally exposed
- Use different service accounts for development and production environments
