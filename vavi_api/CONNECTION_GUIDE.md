# SQL Server Connection Guide

## Common SQL Server Connection Issues

### 1. Check SQL Server Instance Name

SQL Server might be installed as a named instance. Common instances:
- `localhost\SQLEXPRESS` (SQL Server Express)
- `localhost\MSSQLSERVER` (Default instance)
- `localhost\SQL2019` or similar (Named instance)

### 2. Update .env File

Edit `vavi_api/.env` with your SQL Server details:

**For Named Instance (e.g., SQLEXPRESS):**
```
DB_SERVER=localhost\SQLEXPRESS
DB_NAME=VAVI
DB_USER=your_username
DB_PASSWORD=your_password
```

**For Default Instance:**
```
DB_SERVER=localhost
DB_NAME=VAVI
DB_USER=your_username
DB_PASSWORD=your_password
```

**For Remote Server:**
```
DB_SERVER=192.168.1.100
DB_NAME=VAVI
DB_USER=your_username
DB_PASSWORD=your_password
```

**For SQL Server with Port:**
```
DB_SERVER=localhost,1433
DB_NAME=VAVI
DB_USER=your_username
DB_PASSWORD=your_password
```

### 3. Verify SQL Server is Running

1. Open **SQL Server Configuration Manager**
2. Check **SQL Server Services** - make sure SQL Server is running
3. Check **SQL Server Network Configuration** - ensure TCP/IP is enabled

### 4. Test Connection

You can test the connection using `sqlcmd`:
```powershell
sqlcmd -S localhost\SQLEXPRESS -U your_username -P your_password -d VAVI -Q "SELECT @@VERSION"
```

### 5. Common Issues

- **Error 10061**: SQL Server is not running or not accessible
- **Named Instance**: Use `server\instancename` format
- **Windows Authentication**: pymssql requires SQL Authentication (username/password)
- **Firewall**: Ensure port 1433 (or your SQL Server port) is open

### 6. Create Database

If the VAVI database doesn't exist, create it:
```sql
CREATE DATABASE VAVI;
```

Then run your schema scripts to create the tables.

