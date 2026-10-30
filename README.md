# 🛡️ Report System by aKaRi

**Advanced Report System for Counter-Strike 1.6 | AMX Mod X**

A custom-built reporting system for Counter-Strike 1.6 servers, designed to make player reports, bug submissions and community suggestions easier to manage.

Developed with attention to functionality, user experience and a clean administration interface.

---

## 📌 About the Project

**Report System by aKaRi** is an AMX Mod X plugin created for Counter-Strike 1.6 servers.

The plugin provides players with an intuitive in-game reporting menu, allowing them to report problematic players, submit bug reports and share suggestions with the server administration.

All submitted reports are stored in a MySQL database, allowing administrators to access and review them directly from the game.

The system also includes a dedicated administration panel with a custom MOTD interface.

---

## ✨ Features

### 👤 Player Features
- Easy-to-use in-game reporting menu.
- Report other players currently connected to the server.
- Submit bug reports.
- Send suggestions and ideas to the administration.
- Automatic report date and time recording.
- Automatic map identification.
- Interactive player selection menu.
- Player selection with pagination (8 players per page).
- Custom Tutor notifications.
- Colored chat messages.

### 🛠️ Administration Features
- Dedicated administration panel.
- Access reports directly from the game.
- Browse reports submitted by individual players.
- View report history.
- Display report details in a custom MOTD interface.
- Organized report presentation.
- Administrator access controlled by AMXX permissions.

### 🗄️ MySQL Integration
- MySQL database connectivity using AMX Mod X SQLX.
- Automatic creation of the required database table.
- Persistent report storage.
- Asynchronous SQL report handling.
- Automatic database connection recovery.
- Connection error notifications.
- Support for existing BaseBuilder SQL configuration variables.

---

## 🎮 In-Game Commands

| Command | Description |
|---|---|
| `/raport` | Opens the player reporting menu. |
| `/raporty` | Opens the administration report panel. |

Commands are available in both public and team chat.

---

## 🖥️ Administration Access

Access to the administration panel is controlled by the following AMXX flag:

```pawn
#define ADMIN_FLAG_REPORTS ADMIN_BAN
```

By default, the panel requires the **ADMIN_BAN** permission flag.

You can change this permission by modifying the definition in the source code.

---

## ⚙️ Requirements

- Counter-Strike 1.6 dedicated server.
- AMX Mod X.
- AMX Mod X SQLX module.
- MySQL database.
- Appropriate database credentials and permissions.

---

## 📥 Installation

1. Download the repository.
2. Copy `ReportSystem.sma` into your AMXX source directory:

   `addons/amxmodx/scripting/`

3. Compile the plugin using the AMX Mod X compiler.
4. Copy the compiled `.amxx` file into:

   `addons/amxmodx/plugins/`

5. Add the plugin name to:

   `addons/amxmodx/configs/plugins.ini`

6. Configure the MySQL connection.
7. Restart the server or change the map.

The plugin automatically creates the required `reports` table when the database connection is established.

---

## 🗄️ SQL Configuration

The plugin supports the following configuration variables:

```cfg
report_sql_host "YOUR_MYSQL_HOST"
report_sql_user "YOUR_MYSQL_USER"
report_sql_pass "YOUR_MYSQL_PASSWORD"
report_sql_db   "YOUR_MYSQL_DATABASE"
```

**BaseBuilder compatibility**

If the server already uses the following BaseBuilder SQL variables, they take priority over the Report System configuration:

```cfg
bb_sql_host
bb_sql_user
bb_sql_pass
bb_sql_db
```

Make sure your MySQL user has sufficient permissions to create and manage the required table.

**Security notice:** Never publish real database credentials in a public repository. Always use your own secure server configuration.

---

## 🧩 Database Structure

The plugin automatically creates a MySQL table named:

`reports`

Stored information includes:

| Column | Description |
|---|---|
| `id` | Unique report identifier. |
| `name` | Name of the reporting player. |
| `date` | Report date. |
| `time` | Report time. |
| `map` | Map on which the report was submitted. |
| `bug` | Bug report content. |
| `player` | Player report content. |
| `idea` | Suggestion or idea content. |
| `created` | Database creation timestamp. |

---

## 🎨 User Interface

The plugin features a custom in-game menu system and an administration MOTD interface.

The administration interface uses a dark design with green accents, providing a clean and readable presentation of submitted reports.

---

## 🔧 Source Code

The project is written in **Pawn** for AMX Mod X.

Main source file:

`ReportSystem.sma`

The source code can be modified and adapted to individual server requirements.

---

## 👨‍💻 Author

**Created by: aKaRi**

Project: Report System  
Version: 1.3  
Platform: Counter-Strike 1.6  
Framework: AMX Mod X  
Language: Pawn  
Database: MySQL

---

## ⭐ Support & Contributions

If you find this project useful, consider giving the repository a ⭐ on GitHub.

Suggestions, improvements and bug reports are welcome.

---

---

## 📸 Screenshots

Take a look at Report System by aKaRi in action.

### Main Menu
![Main Menu](screenshots/main-menu.png)

### Info Tutor
![Report Menu](screenshots/report-menu.png)

### Administration Panel
![Administration Panel](screenshots/admin-panel.png)

---

**Report System by aKaRi** – Designed for Counter-Strike 1.6 servers.
**Report System by aKaRi**  
*Making Counter-Strike 1.6 server administration easier, one report at a time.*
