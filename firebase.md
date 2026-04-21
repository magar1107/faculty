https://faculty-188b6-default-rtdb.asia-southeast1.firebasedatabase.app/




Your project
Project name
faculty
Project ID
faculty-188b6
Project number
811208997285
Environment
This setting customises your project for different stages of the app lifecycle
Environment type
Unspecified
Your apps
Android apps
com.faculty
Web apps
faculty
Web app
SDK setup and configuration
Need to reconfigure the Firebase SDKs for your app? Revisit the SDK setup instructions or just download the configuration file containing keys and identifiers for your app.
App ID
1:811208997285:android:96f2519254b270da8a504c
App nickname
Add a nickname
Package name
com.faculty
SHA certificate fingerprints
Type
Actions


roject settings
General
Cloud Messaging
Integration
Service accounts
Data privacy
Users and permissions
Alerts
Your project
Project name
faculty
Project ID
faculty-188b6
Project number
811208997285
Environment
This setting customises your project for different stages of the app lifecycle
Environment type
Unspecified
Your apps
Android apps
com.faculty
Web apps
faculty
Web app
App nickname
faculty
App ID
1:811208997285:web:024b88378f4dcceb8a504c
SDK setup and configuration

npm

CDN

Config
If you're already using NPM and a module bundler such as webpack or Rollup, you can run the following command to install the latest SDK (Learn more):

npm install firebase
Then, initialise Firebase and begin using the SDKs for the products that you'd like to use.

// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyDCUzB3T_2PrwiSU3SIVjQzQsmoYW4E8Q0",
  authDomain: "faculty-188b6.firebaseapp.com",
  databaseURL: "https://faculty-188b6-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "faculty-188b6",
  storageBucket: "faculty-188b6.firebasestorage.app",
  messagingSenderId: "811208997285",
  appId: "1:811208997285:web:024b88378f4dcceb8a504c",
  measurementId: "G-T2H8P142ZB"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);


oogle json 
{
  "project_info": {
    "project_number": "811208997285",
    "firebase_url": "https://faculty-188b6-default-rtdb.asia-southeast1.firebasedatabase.app",
    "project_id": "faculty-188b6",
    "storage_bucket": "faculty-188b6.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:811208997285:android:96f2519254b270da8a504c",
        "android_client_info": {
          "package_name": "com.faculty"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSyBLiK_4PDlYpeMcMfgQXkZ8iuvhwR2rUoQ"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}