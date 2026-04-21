Here is a **complete screen-by-screen, button-by-button, widget-by-widget** breakdown for your **Faculty Substitution Automation System** using **Firebase Realtime Database**.

You will not write code. You will use these prompts to build the UI/UX and logic.

## Core Logic (No Manual Substitution)
- **Admin** marks a faculty as "Absent".
- **System** automatically:
  1. Reads the absent faculty's subject.
  2. Scans all other faculty for the **same subject skill**.
  3. Finds the **most free** (least classes that day) matching faculty.
  4. Auto-assigns substitution.
  5. Notifies both faculty.

---

## Screen 1: Login Screen

```
┌─────────────────────────────────────────┐
│            SUBSTITUTE AUTO              │
│                  v1.0                   │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │           Email Address           │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │            Password               │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │            LOGIN BUTTON           │  │
│  └───────────────────────────────────┘  │
│                                         │
│  [ Firebase Auth - No manual role entry│
│    Role detected from DB automatically ]│
└─────────────────────────────────────────┘
```

### Buttons & Widgets (Line by line):
1. **AppBar Title** = "Substitute Auto"
2. **Email TextField** (hint: "faculty@college.edu")
3. **Password TextField** (obscure text = true)
4. **Login Button** → checks Firebase → redirects to:
   - `AdminDashboard` if role = "admin"
   - `FacultyDashboard` if role = "faculty"
5. **No Signup button** (only admin adds faculty via DB)

---

## Screen 2: Admin Dashboard (Main Auto-Substitution Screen)

```
┌─────────────────────────────────────────┐
│ [≡]  SUBSTITUTE AUTO    [Admin]   [🔄]  │
├─────────────────────────────────────────┤
│                                         │
│  TODAY'S TIMETABLE SNAPSHOT             │
│  ┌────────────────────────────────────┐ │
│  │ 9:00  │ Maths  │ Dr. Sharma │ [ABSENT]│
│  │10:00  │ Physics│ Prof. Verma │ Present │
│  │11:00  │ CS     │ Dr. Mehta   │ Present │
│  │12:00  │ Maths  │ Dr. Sharma │ [ABSENT]│
│  └────────────────────────────────────┘ │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │   MARK ABSENT (Quick Action)       │ │
│  │  ┌──────────┐ ┌──────────┐        │ │
│  │  │ Dr.Sharma│ │Prof.Verma│        │ │
│  │  └──────────┘ └──────────┘        │ │
│  │  ┌──────────┐                     │ │
│  │  │ Dr.Mehta │                     │ │
│  │  └──────────┘                     │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │     AUTO-SUBSTITUTE STATUS         │ │
│  │  ✅ Dr.Sharma (Maths) → Absent     │ │
│  │  🔄 System Auto-Matched:           │ │
│  │     Prof.Verma (Maths skill)       │ │
│  │     Free at 9:00 & 12:00           │ │
│  │  📢 Substituted automatically!     │ │
│  └────────────────────────────────────┘ │
│                                         │
│  [ EXPORT REPORT ]  [ VIEW ALL LOGS ]   │
└─────────────────────────────────────────┘
```

### Buttons & Widgets (Line by line):
1. **Drawer Icon** (≡) → logout, profile, settings
2. **Title** = "SUBSTITUTE AUTO"
3. **Role Badge** = "Admin" (colored background)
4. **Refresh Button** (🔄) → reloads today's schedule from Firebase
5. **Timetable ListView** (card per period):
   - Time, Subject, Faculty Name, Status chip
   - **Absent Button** (red) on each row → triggers auto-substitution
6. **Quick Action Chip Row**:
   - List of all faculty names as chips
   - Tap any chip → marks that faculty absent for current period
7. **Auto-Substitute Status Card** (read-only, auto-populated):
   - Shows absent faculty & their subject
   - Shows **system-suggested substitute** (matched by subject skill)
   - Shows why chosen (free period)
   - Green checkmark = auto-assigned
8. **Export Report Button** → downloads JSON/CSV of substitutions
9. **View All Logs Button** → shows history from Firebase

---

## Screen 3: What Happens When Admin Presses "ABSENT"

No manual substitution screen appears. Instead, **a bottom sheet or dialog auto-shows**:

```
┌─────────────────────────────────────────┐
│   ⚠️ MARKING ABSENT: Dr. Sharma        │
│   Subject: Mathematics (Code: MTH101)   │
├─────────────────────────────────────────┤
│                                         │
│   🔍 SCANNING FOR MATCHING SKILL...     │
│                                         │
│   ✅ System found substitute:           │
│   ┌───────────────────────────────────┐ │
│   │ 👩‍🏫 Prof. Verma                    │ │
│   │ 📚 Also teaches Mathematics       │ │
│   │ 🕒 Free at 9:00 & 12:00           │ │
│   │ ✅ Already assigned automatically │ │
│   └───────────────────────────────────┘ │
│                                         │
│   [ OK ]  [ View Substitution Log ]     │
└─────────────────────────────────────────┘
```

### No manual override button (unless you want one later)
- **Auto-substitution is instantaneous**
- Data written to Firebase:  
  `/substitutions/{date}/{periodId}`  
  `/faculty/{facultyId}/substitutions`

---

## Screen 4: Faculty Dashboard (Read-Only View)

```
┌─────────────────────────────────────────┐
│ [≡]  SUBSTITUTE AUTO  [Faculty]   [🔄]  │
├─────────────────────────────────────────┤
│                                         │
│  👋 Hello, Prof. Verma                  │
│                                         │
│  ┌──────────────┬──────────────────────┐│
│  │ MY TODAY     │  SUBSTITUTION ALERTS ││
│  │ SCHEDULE     │                      ││
│  │ 9:00 Maths   │  ✅ You substituted  ││
│  │10:00 Free    │     Dr.Sharma (Maths)││
│  │11:00 CS      │     at 9:00 AM       ││
│  │12:00 Free    │                      ││
│  └──────────────┴──────────────────────┘│
│                                         │
│  ┌────────────────────────────────────┐ │
│  │  NOTIFICATIONS (Auto-push)         │ │
│  │  🔔 System assigned you to take    │ │
│  │     Maths for Dr.Sharma at 9:00    │ │
│  │     [ Accept ] [ Report Issue ]    │ │
│  └────────────────────────────────────┘ │
│                                         │
│  [ MY SUBSTITUTION HISTORY ]            │
└─────────────────────────────────────────┘
```

### Buttons & Widgets:
1. **Faculty Name Greeting**
2. **My Today Schedule Card** (from Firebase)
3. **Substitution Alerts Card**:
   - Lists classes you are substituting for
4. **Notification Card** (real-time listener on Firebase):
   - **Accept Button** → confirms substitution
   - **Report Issue Button** → notifies admin
5. **My Substitution History Button** → past substitutions

---

## Screen 5: Firebase Realtime Database Structure (JSON)

Use this exact schema:

```json
{
  "faculty": {
    "facultyId_001": {
      "name": "Dr. Sharma",
      "email": "sharma@college.edu",
      "role": "faculty",
      "skills": ["Mathematics", "Statistics"],
      "subjects": ["MTH101", "MTH102"]
    },
    "facultyId_002": {
      "name": "Prof. Verma",
      "skills": ["Mathematics", "Physics"]
    }
  },
  
  "timetable": {
    "2026-04-21": {
      "9:00": {
        "subject": "Mathematics",
        "facultyId": "facultyId_001",
        "room": "201"
      },
      "10:00": {
        "subject": "Physics",
        "facultyId": "facultyId_002"
      }
    }
  },
  
  "attendance": {
    "2026-04-21": {
      "9:00": {
        "facultyId": "facultyId_001",
        "status": "absent",
        "substituteId": "facultyId_002",
        "autoAssigned": true,
        "timestamp": 1713715200000
      }
    }
  },
  
  "substitutionLogs": {
    "auto_1713715200000": {
      "date": "2026-04-21",
      "period": "9:00",
      "absentFaculty": "Dr. Sharma",
      "substituteFaculty": "Prof. Verma",
      "subject": "Mathematics",
      "method": "auto-skill-match"
    }
  }
}
```

---

## Simple Flow (If you want even simpler)

If you want **no buttons at all for substitution**:

1. **Admin Dashboard** shows list of faculty with a **Toggle (Present/Absent)**.
2. Admin flips toggle to "Absent".
3. **Auto-trigger**:
   - Firebase listener detects change
   - Cloud Function (or local app logic) runs matching algorithm
   - Writes substitute to `attendance` node
4. Faculty app gets real-time update.
5. **No "Suggest" button** → it's fully automatic.

---

## Your Final Prompt to Build This (Copy-Paste to AI/Developer)

> Build a Faculty Substitution Automation app using Flutter + Firebase Realtime Database.  
> Features:  
> - Login (admin & faculty roles from DB)  
> - Admin sees today's timetable with "Absent" button per faculty  
> - On pressing Absent, system automatically finds another faculty with same subject skill and least classes that day  
> - Auto-assign substitution without any manual selection  
> - Faculty sees their schedule + substitution alerts with Accept button  
> - All data stored in Firebase JSON structure provided above  
> - No manual substitution screen, fully automatic  

## How System Knows Admin vs Faculty Login (Firebase Method)

### Simple Answer:
**You don't need separate login screens.** The system checks role from Firebase **AFTER** login using email.

---

## Complete Flow (Button by Button, Line by Line)

### Step 1: Login Screen (Same for everyone)

```
┌─────────────────────────────────────────┐
│            SUBSTITUTE AUTO              │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │    faculty@college.edu            │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │    •••••••••••                    │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │           LOGIN BUTTON            │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### Step 2: What Happens When User Presses LOGIN Button

```
┌────────────────────────────────────────────────────────┐
│ 1. Get email + password from text fields              │
│ 2. Send to Firebase Authentication                    │
│ 3. If login FAILS → show "Invalid credentials"        │
│ 4. If login SUCCESS → get email (e.g., admin@college.edu) │
│ 5. Query Firebase Realtime Database:                  │
│                                                       │
│    "faculty" node → search for this email            │
│                                                       │
│ 6. Check the "role" field:                           │
│                                                       │
│    if role == "admin" → go to AdminDashboard         │
│    if role == "faculty" → go to FacultyDashboard     │
│    if role NOT FOUND → show error + logout           │
└────────────────────────────────────────────────────────┘
```

---

## Step 3: Firebase Database Structure for Role Detection

```json
{
  "faculty": {
    "admin_001": {
      "name": "Dr. Principal",
      "email": "admin@college.edu",
      "role": "admin",
      "password": "hashed_here"  // optional if using Firebase Auth
    },
    "faculty_001": {
      "name": "Dr. Sharma",
      "email": "sharma@college.edu",
      "role": "faculty",
      "skills": ["Mathematics"],
      "subjects": ["MTH101"]
    },
    "faculty_002": {
      "name": "Prof. Verma",
      "email": "verma@college.edu",
      "role": "faculty",
      "skills": ["Mathematics", "Physics"],
      "subjects": ["MTH101", "PHY101"]
    }
  }
}
```

---

## Step 4: Role Detection Logic (Simple Pseudo-Code)

```
ON LOGIN BUTTON CLICK:

  email = emailTextField.text
  password = passwordTextField.text
  
  authenticateWithFirebase(email, password)
  
  IF authentication success:
  
    database.ref("faculty").orderByChild("email").equalTo(email).get()
    
    IF data exists:
      role = data["role"]
      
      IF role == "admin":
        navigate to AdminDashboardScreen()
        
      ELSE IF role == "faculty":
        navigate to FacultyDashboardScreen()
        
      ELSE:
        showToast("Unknown role. Contact admin")
        logout()
        
    ELSE:
      showToast("User not found in faculty list")
      logout()
      
  ELSE:
    showToast("Login failed")
```

---

## Step 5: Visual Representation (How App Knows)

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Login       │     │  Firebase    │     │  Dashboard   │
│  Screen      │────▶│  Auth + DB   │────▶│  Different   │
│              │     │              │     │  for each    │
└──────────────┘     └──────────────┘     └──────────────┘
                                                 │
                    ┌────────────────────────────┼────────────────────────────┐
                    │                            │                            │
                    ▼                            ▼                            ▼
            ┌──────────────┐            ┌──────────────┐            ┌──────────────┐
            │ Admin sees:  │            │ Faculty sees:│            │ Error sees:  │
            │ - Mark absent│            │ - My schedule│            │ - Try again  │
            │ - Auto-sub   │            │ - Alerts     │            │ - Contact    │
            │ - All logs   │            │ - Accept sub │            │   support    │
            └──────────────┘            └──────────────┘            └──────────────┘
```

---

## Step 6: What Admin Sees vs Faculty Sees (Side by Side)

| **Admin Dashboard** | **Faculty Dashboard** |
|---------------------|----------------------|
| Today's timetable | My today schedule |
| MARK ABSENT button on each faculty | NO mark absent button |
| Auto-substitution status card | Substitution alerts card |
| Export report button | Accept/Report buttons |
| View all logs button | My history button |
| Can see all faculty data | Can see only own data |

---

## Step 7: Simple Alternative (No Firebase Auth)

If you want **even simpler** (just email check, no password):

```
Login Screen:
- Email field only (no password)
- CONTINUE button

On CONTINUE click:
1. Check if email exists in "faculty" node
2. Get role from that record
3. Directly go to role-specific dashboard

No authentication needed (useful for internal college app)
```

---

## Step 8: Role Check Widget (Visual on Dashboard)

**Admin Dashboard Header:**
```
┌─────────────────────────────────────────┐
│ [≡]  SUBSTITUTE AUTO    [👑 ADMIN]  [🔄]│
└─────────────────────────────────────────┘
```

**Faculty Dashboard Header:**
```
┌─────────────────────────────────────────┐
│ [≡]  SUBSTITUTE AUTO    [👨‍🏫 FACULTY] [🔄]│
└─────────────────────────────────────────┘
```

---
## Complete Firebase Realtime Database JSON Structure

Here is the **complete, ready-to-use JSON** for your Faculty Substitution Automation System:

```json
{
  "faculty": {
    "admin_001": {
      "name": "Dr. Principal Kumar",
      "email": "admin@college.edu",
      "role": "admin",
      "phone": "+91 98765 43210",
      "joinedDate": "2024-01-01",
      "isActive": true
    },
    "faculty_001": {
      "name": "Dr. Amit Sharma",
      "email": "amit.sharma@college.edu",
      "role": "faculty",
      "phone": "+91 98765 43211",
      "department": "Mathematics",
      "skills": ["Mathematics", "Statistics", "Linear Algebra"],
      "subjects": ["MTH101", "MTH102", "STA201"],
      "maxWeeklyHours": 24,
      "joinedDate": "2024-06-15",
      "isActive": true
    },
    "faculty_002": {
      "name": "Prof. Sunita Verma",
      "email": "sunita.verma@college.edu",
      "role": "faculty",
      "phone": "+91 98765 43212",
      "department": "Mathematics",
      "skills": ["Mathematics", "Applied Mathematics", "Calculus"],
      "subjects": ["MTH101", "MTH103", "CAL202"],
      "maxWeeklyHours": 24,
      "joinedDate": "2024-08-20",
      "isActive": true
    },
    "faculty_003": {
      "name": "Dr. Rajesh Mehta",
      "email": "rajesh.mehta@college.edu",
      "role": "faculty",
      "phone": "+91 98765 43213",
      "department": "Computer Science",
      "skills": ["Programming", "Data Structures", "Algorithms", "Python"],
      "subjects": ["CS101", "CS201", "CS301", "PYT101"],
      "maxWeeklyHours": 24,
      "joinedDate": "2024-01-10",
      "isActive": true
    },
    "faculty_004": {
      "name": "Prof. Neha Gupta",
      "email": "neha.gupta@college.edu",
      "role": "faculty",
      "phone": "+91 98765 43214",
      "department": "Computer Science",
      "skills": ["Programming", "Web Development", "JavaScript", "React"],
      "subjects": ["CS101", "WD201", "REACT301"],
      "maxWeeklyHours": 24,
      "joinedDate": "2024-09-01",
      "isActive": true
    },
    "faculty_005": {
      "name": "Dr. Vikram Singh",
      "email": "vikram.singh@college.edu",
      "role": "faculty",
      "phone": "+91 98765 43215",
      "department": "Physics",
      "skills": ["Physics", "Mechanics", "Thermodynamics", "Quantum Physics"],
      "subjects": ["PHY101", "PHY201", "MEC301", "QP401"],
      "maxWeeklyHours": 24,
      "joinedDate": "2024-03-15",
      "isActive": true
    },
    "faculty_006": {
      "name": "Prof. Anjali Nair",
      "email": "anjali.nair@college.edu",
      "role": "faculty",
      "phone": "+91 98765 43216",
      "department": "Physics",
      "skills": ["Physics", "Electronics", "Optics"],
      "subjects": ["PHY101", "ELC201", "OPT301"],
      "maxWeeklyHours": 24,
      "joinedDate": "2024-07-10",
      "isActive": true
    }
  },

  "timetable": {
    "2026-04-21": {
      "period_1": {
        "time": "09:00 AM",
        "endTime": "10:00 AM",
        "subject": "MTH101",
        "subjectName": "Mathematics",
        "facultyId": "faculty_001",
        "facultyName": "Dr. Amit Sharma",
        "room": "Room 201",
        "semester": 3,
        "batch": "CS-A"
      },
      "period_2": {
        "time": "10:00 AM",
        "endTime": "11:00 AM",
        "subject": "PHY101",
        "subjectName": "Physics",
        "facultyId": "faculty_005",
        "facultyName": "Dr. Vikram Singh",
        "room": "Room 105",
        "semester": 3,
        "batch": "CS-A"
      },
      "period_3": {
        "time": "11:00 AM",
        "endTime": "12:00 PM",
        "subject": "CS101",
        "subjectName": "Computer Science",
        "facultyId": "faculty_003",
        "facultyName": "Dr. Rajesh Mehta",
        "room": "Lab 301",
        "semester": 3,
        "batch": "CS-A"
      },
      "period_4": {
        "time": "12:00 PM",
        "endTime": "01:00 PM",
        "subject": "MTH102",
        "subjectName": "Advanced Mathematics",
        "facultyId": "faculty_001",
        "facultyName": "Dr. Amit Sharma",
        "room": "Room 201",
        "semester": 3,
        "batch": "CS-B"
      },
      "period_5": {
        "time": "02:00 PM",
        "endTime": "03:00 PM",
        "subject": "CS201",
        "subjectName": "Data Structures",
        "facultyId": "faculty_003",
        "facultyName": "Dr. Rajesh Mehta",
        "room": "Lab 302",
        "semester": 4,
        "batch": "CS-A"
      },
      "period_6": {
        "time": "03:00 PM",
        "endTime": "04:00 PM",
        "subject": "MTH103",
        "subjectName": "Applied Mathematics",
        "facultyId": "faculty_002",
        "facultyName": "Prof. Sunita Verma",
        "room": "Room 202",
        "semester": 4,
        "batch": "CS-B"
      }
    },
    "2026-04-22": {
      "period_1": {
        "time": "09:00 AM",
        "endTime": "10:00 AM",
        "subject": "CS101",
        "subjectName": "Computer Science",
        "facultyId": "faculty_004",
        "facultyName": "Prof. Neha Gupta",
        "room": "Lab 301",
        "semester": 3,
        "batch": "CS-A"
      },
      "period_2": {
        "time": "10:00 AM",
        "endTime": "11:00 AM",
        "subject": "MTH101",
        "subjectName": "Mathematics",
        "facultyId": "faculty_002",
        "facultyName": "Prof. Sunita Verma",
        "room": "Room 201",
        "semester": 3,
        "batch": "CS-A"
      }
    }
  },

  "attendance": {
    "2026-04-21": {
      "period_1": {
        "facultyId": "faculty_001",
        "facultyName": "Dr. Amit Sharma",
        "subject": "MTH101",
        "status": "absent",
        "substituteId": "faculty_002",
        "substituteName": "Prof. Sunita Verma",
        "autoAssigned": true,
        "assignedAt": "2026-04-21T08:30:00.000Z",
        "substitutionStatus": "accepted",
        "remarks": ""
      },
      "period_2": {
        "facultyId": "faculty_005",
        "facultyName": "Dr. Vikram Singh",
        "subject": "PHY101",
        "status": "present",
        "substituteId": null,
        "substituteName": null,
        "autoAssigned": false,
        "assignedAt": null,
        "substitutionStatus": null,
        "remarks": ""
      },
      "period_3": {
        "facultyId": "faculty_003",
        "facultyName": "Dr. Rajesh Mehta",
        "subject": "CS101",
        "status": "present",
        "substituteId": null,
        "substituteName": null,
        "autoAssigned": false,
        "assignedAt": null,
        "substitutionStatus": null,
        "remarks": ""
      },
      "period_4": {
        "facultyId": "faculty_001",
        "facultyName": "Dr. Amit Sharma",
        "subject": "MTH102",
        "status": "absent",
        "substituteId": "faculty_002",
        "substituteName": "Prof. Sunita Verma",
        "autoAssigned": true,
        "assignedAt": "2026-04-21T08:30:00.000Z",
        "substitutionStatus": "pending",
        "remarks": ""
      }
    }
  },

  "substitutionLogs": {
    "auto_20260421_001": {
      "id": "auto_20260421_001",
      "date": "2026-04-21",
      "period": "period_1",
      "time": "09:00 AM",
      "absentFacultyId": "faculty_001",
      "absentFacultyName": "Dr. Amit Sharma",
      "absentFacultyEmail": "amit.sharma@college.edu",
      "substituteFacultyId": "faculty_002",
      "substituteFacultyName": "Prof. Sunita Verma",
      "substituteFacultyEmail": "sunita.verma@college.edu",
      "subject": "MTH101",
      "subjectName": "Mathematics",
      "room": "Room 201",
      "batch": "CS-A",
      "method": "auto-skill-match",
      "matchReason": "Same subject skill (Mathematics), Free at 09:00 AM & 12:00 PM",
      "assignedBy": "system",
      "assignedAt": "2026-04-21T08:30:00.000Z",
      "status": "accepted",
      "acceptedAt": "2026-04-21T08:35:00.000Z"
    },
    "auto_20260421_002": {
      "id": "auto_20260421_002",
      "date": "2026-04-21",
      "period": "period_4",
      "time": "12:00 PM",
      "absentFacultyId": "faculty_001",
      "absentFacultyName": "Dr. Amit Sharma",
      "absentFacultyEmail": "amit.sharma@college.edu",
      "substituteFacultyId": "faculty_002",
      "substituteFacultyName": "Prof. Sunita Verma",
      "substituteFacultyEmail": "sunita.verma@college.edu",
      "subject": "MTH102",
      "subjectName": "Advanced Mathematics",
      "room": "Room 201",
      "batch": "CS-B",
      "method": "auto-skill-match",
      "matchReason": "Same subject skill (Mathematics), Already substituting period_1, Available",
      "assignedBy": "system",
      "assignedAt": "2026-04-21T08:30:00.000Z",
      "status": "pending",
      "acceptedAt": null
    }
  },

  "facultyAvailability": {
    "faculty_001": {
      "2026-04-21": {
        "period_1": "busy",
        "period_2": "busy",
        "period_3": "free",
        "period_4": "busy",
        "period_5": "free",
        "period_6": "free"
      }
    },
    "faculty_002": {
      "2026-04-21": {
        "period_1": "free",
        "period_2": "free",
        "period_3": "free",
        "period_4": "free",
        "period_5": "free",
        "period_6": "busy"
      }
    },
    "faculty_003": {
      "2026-04-21": {
        "period_1": "free",
        "period_2": "free",
        "period_3": "busy",
        "period_4": "free",
        "period_5": "busy",
        "period_6": "free"
      }
    },
    "faculty_004": {
      "2026-04-21": {
        "period_1": "free",
        "period_2": "free",
        "period_3": "free",
        "period_4": "free",
        "period_5": "free",
        "period_6": "free"
      }
    },
    "faculty_005": {
      "2026-04-21": {
        "period_1": "free",
        "period_2": "busy",
        "period_3": "free",
        "period_4": "free",
        "period_5": "free",
        "period_6": "free"
      }
    }
  },

  "notifications": {
    "notification_001": {
      "id": "notification_001",
      "toFacultyId": "faculty_002",
      "toFacultyEmail": "sunita.verma@college.edu",
      "title": "Substitution Assignment",
      "message": "You have been assigned to substitute for Dr. Amit Sharma (Mathematics) at 09:00 AM in Room 201",
      "type": "substitution",
      "relatedLogId": "auto_20260421_001",
      "isRead": false,
      "createdAt": "2026-04-21T08:30:00.000Z",
      "actions": ["accept", "report"]
    },
    "notification_002": {
      "id": "notification_002",
      "toFacultyId": "faculty_002",
      "toFacultyEmail": "sunita.verma@college.edu",
      "title": "Substitution Assignment",
      "message": "You have been assigned to substitute for Dr. Amit Sharma (Advanced Mathematics) at 12:00 PM in Room 201",
      "type": "substitution",
      "relatedLogId": "auto_20260421_002",
      "isRead": false,
      "createdAt": "2026-04-21T08:30:00.000Z",
      "actions": ["accept", "report"]
    }
  },

  "subjectsDatabase": {
    "MTH101": {
      "name": "Mathematics",
      "department": "Mathematics",
      "semester": 3,
      "credits": 4,
      "qualifiedFaculty": ["faculty_001", "faculty_002"]
    },
    "MTH102": {
      "name": "Advanced Mathematics",
      "department": "Mathematics",
      "semester": 3,
      "credits": 4,
      "qualifiedFaculty": ["faculty_001", "faculty_002"]
    },
    "MTH103": {
      "name": "Applied Mathematics",
      "department": "Mathematics",
      "semester": 4,
      "credits": 3,
      "qualifiedFaculty": ["faculty_002"]
    },
    "CS101": {
      "name": "Computer Science",
      "department": "Computer Science",
      "semester": 3,
      "credits": 4,
      "qualifiedFaculty": ["faculty_003", "faculty_004"]
    },
    "CS201": {
      "name": "Data Structures",
      "department": "Computer Science",
      "semester": 4,
      "credits": 4,
      "qualifiedFaculty": ["faculty_003"]
    },
    "PHY101": {
      "name": "Physics",
      "department": "Physics",
      "semester": 3,
      "credits": 4,
      "qualifiedFaculty": ["faculty_005", "faculty_006"]
    }
  },

  "settings": {
    "autoSubstitution": {
      "enabled": true,
      "matchAlgorithm": "skill-based",
      "allowMultipleSubstitutions": true,
      "maxSubstitutionsPerDay": 3,
      "notifyViaEmail": true,
      "notifyViaApp": true,
      "requireAcceptance": true,
      "acceptanceTimeoutMinutes": 30
    },
    "collegeInfo": {
      "name": "College of Engineering",
      "code": "COE001",
      "timezone": "Asia/Kolkata",
      "academicYear": "2025-2026",
      "semester": "Odd"
    }
  },

  "reports": {
    "2026-04-21": {
      "totalAbsent": 2,
      "totalSubstitutions": 2,
      "autoAssigned": 2,
      "manualAssigned": 0,
      "acceptedCount": 1,
      "pendingCount": 1,
      "rejectedCount": 0,
      "generatedAt": "2026-04-21T17:00:00.000Z"
    }
  }
}
```

---

## How to Use This JSON:

### Step 1: Import to Firebase
1. Go to Firebase Console → Realtime Database
2. Click on the 3 dots (⋮) → **Import JSON**
3. Paste this entire JSON
4. Click **Import**

### Step 2: Set Firebase Rules (Security)

```json
{
  "rules": {
    "faculty": {
      ".read": "auth != null",
      ".write": "auth != null && data.child('role').val() == 'admin'"
    },
    "attendance": {
      ".read": "auth != null",
      ".write": "auth != null && (data.child('faculty/' + auth.uid + '/role').val() == 'admin' || auth.uid == newData.child('substituteId').val())"
    },
    "substitutionLogs": {
      ".read": "auth != null",
      ".write": "auth != null && root.child('faculty/' + auth.uid + '/role').val() == 'admin'"
    },
    "notifications": {
      ".read": "auth != null && (root.child('faculty/' + auth.uid + '/role').val() == 'admin' || auth.uid == newData.child('toFacultyId').val())",
      ".write": "auth != null"
    }
  }
}
```

### Step 3: Test Credentials

| Role | Email | Role Field |
|------|-------|-------------|
| Admin | admin@college.edu | "admin" |
| Faculty 1 | amit.sharma@college.edu | "faculty" |
| Faculty 2 | sunita.verma@college.edu | "faculty" |
| Faculty 3 | rajesh.mehta@college.edu | "faculty" |

---


## Auto-Substitution Algorithm (How System Matches)

When admin marks `faculty_001` absent for `MTH101`:

```
1. Get subject = "MTH101"
2. Look in subjectsDatabase → qualifiedFaculty = ["faculty_001", "faculty_002"]
3. Remove absent faculty → remaining = ["faculty_002"]
4. Check facultyAvailability for faculty_002 on that date & time
5. If free → assign automatically
6. Create record in attendance with substituteId = "faculty_002"
7. Create notification for faculty_002
8. Log in substitutionLogs
```

This JSON is **production-ready**. Just import and connect your app!


google json 
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