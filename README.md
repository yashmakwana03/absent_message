# 📱 Attendance Manager

> **Smart. Fast. Reliable.**
> An offline-first mobile application designed to streamline the attendance process for Class Representatives (CRs) and faculty. Built with Flutter & SQLite to replace manual methods and enable easy message generation.

---

## 🚀 Overview

**Attendance Manager** is my personal project as a Class Representative (CR) at RK University. For the past two years, I've been responsible for taking attendance and generating absent messages for our parent groups. Initially, I built a simple website using inline CSS and JavaScript with a dictionary-based system, but it had limitations – no offline storage, no easy way to save attendance logs for later use.

In my 5th semester, I learned Flutter as part of my curriculum, and I saw an opportunity to create a better solution. This app replaces my old website, offering offline functionality with SQLite, quick attendance marking, and the ability to generate shareable messages. Now, when faculty ask for attendance or reviews, I can instantly provide HTML files they can copy-paste or text summaries, making everyone's life easier.

As a 3rd-year Computer Science student, I'm passionate about building tools that solve real problems, and this app reflects my journey from basic web development to mobile app creation.

## ✨ Key Features

- **⚡ Quick Actions:** Mark attendance for a whole class in seconds.
- **📊 Dashboard:** Real-time view of daily stats and shortcuts.
- **🔍 Smart Search:** Instantly find student records by name or ID.
- **📂 Local Database:** Powered by **SQLite** for instant loading and 100% offline access – something my old website couldn't do.
- **🛡️ Data Safety:** Built-in **Backup & Restore** functionality to keep attendance logs safe.
- **🎓 Student Management:** Add, edit, or delete student profiles and organize them by department.
- **📈 Analytics:** View attendance percentages per student or per class.
- **💬 Message Generation:** Create and share absent messages for parent groups, forwarding to faculty first.
- **📤 Export Options:** Generate HTML files for faculty to fill online attendance or text for daily reviews.

---

## 📸 App Tour

### **1. Getting Started**

|                    **Splash Screen**                     |                   **Home Dashboard**                   |                        **Add Student**                        |
| :------------------------------------------------------: | :----------------------------------------------------: | :-----------------------------------------------------------: |
| <img src="assets/screenshots/splash.jpeg" width="250" /> | <img src="assets/screenshots/home.jpeg" width="250" /> | <img src="assets/screenshots/add_student.jpeg" width="250" /> |
|             _Modern animated splash screen._             |           _Central hub with Quick Actions._            |          _Easily add students manually or in bulk._           |

<br>

### **2. Attendance Management**

|                        **Take Attendance**                        |                      **Daily Dashboard**                      |                    **Export Reports**                    |
| :---------------------------------------------------------------: | :-----------------------------------------------------------: | :------------------------------------------------------: |
| <img src="assets/screenshots/take_attendance.jpeg" width="250" /> | <img src="assets/screenshots/daily_stats.jpeg" width="250" /> | <img src="assets/screenshots/export.jpeg" width="250" /> |
|                  _Mark absent students quickly._                  |                _View daily breakdown & stats._                |          _Generate reports for specific dates._          |

<br>

### **3. Student Analytics & Data**

|                        **Student List**                        |                        **Student Profile**                        |                   **Backup & Restore**                   |
| :------------------------------------------------------------: | :---------------------------------------------------------------: | :------------------------------------------------------: |
| <img src="assets/screenshots/student_list.jpeg" width="250" /> | <img src="assets/screenshots/student_profile.jpeg" width="250" /> | <img src="assets/screenshots/backup.jpeg" width="250" /> |
|                 _Search and view class lists._                 |             _Detailed individual attendance reports._             |             _Secure your data with one tap._             |

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (Dart) – Learned in 5th semester
- **Database:** SQLite (`sqflite`) – For offline attendance logs
- **State Management:** Native (`setState`) & MVC Pattern
- **Key Packages:**
  - `flutter_native_splash` (Branding)
  - `share_plus` (Sharing Messages & Exports)
  - `path_provider` (File System Access)
  - `intl` (Date Formatting)

---

## 📲 Installation & Setup

1.  **Clone the Repo**

    ```bash
    git clone https://github.com/yashmakwana03/attendance_manager.git
    ```

2.  **Install Dependencies**

    ```bash
    flutter pub get
    ```

3.  **Run the App**
    ```bash
    flutter run
    ```

---

## 👨‍💻 Developer

**Yash Makwana**

- 🎓 3rd Year Computer Science Student at RK University
- 💼 Class Representative (CR) for 2+ years
- 📧 [yashmakwana2275@gmail.com](mailto:yashmakwana2275@gmail.com)
- 🔗 [LinkedIn Profile](https://www.linkedin.com/in/yashmakwana03/)

This app is a result of my real-world responsibilities as a CR. What started as a simple website evolved into a full-fledged mobile app thanks to Flutter. I believe in creating tools that make life easier for students, faculty, and myself. If you're a CR or student developer, feel free to use or improve this!

---

_⭐ If you find this project useful, please give it a star on GitHub!_
