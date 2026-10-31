# Minimal read-only SQLite access through Windows' built-in winsqlite3.dll.
# Dot-source this file, then:  $rows = Invoke-SqliteQuery $dbPath "SELECT ..."
# Each row is an ordered dictionary of column name -> value ($null for NULL).

if (-not ("WinSqlite" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Runtime.InteropServices;
using System.Text;

public static class WinSqlite
{
    const int SQLITE_ROW = 100, SQLITE_DONE = 101, SQLITE_OPEN_READONLY = 1;
    const int SQLITE_INTEGER = 1, SQLITE_FLOAT = 2, SQLITE_TEXT = 3, SQLITE_BLOB = 4, SQLITE_NULL = 5;

    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int sqlite3_open_v2(byte[] filename, out IntPtr db, int flags, IntPtr vfs);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int sqlite3_close(IntPtr db);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int nByte, out IntPtr stmt, IntPtr tail);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int sqlite3_step(IntPtr stmt);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int sqlite3_finalize(IntPtr stmt);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int sqlite3_column_count(IntPtr stmt);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern IntPtr sqlite3_column_name(IntPtr stmt, int i);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int sqlite3_column_type(IntPtr stmt, int i);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern long sqlite3_column_int64(IntPtr stmt, int i);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern double sqlite3_column_double(IntPtr stmt, int i);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern IntPtr sqlite3_column_text(IntPtr stmt, int i);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int sqlite3_column_bytes(IntPtr stmt, int i);
    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)]
    static extern IntPtr sqlite3_errmsg(IntPtr db);

    static byte[] Utf8Z(string s) { return Encoding.UTF8.GetBytes(s + "\0"); }

    static string Utf8(IntPtr p, int len)
    {
        if (p == IntPtr.Zero) return null;
        byte[] b = new byte[len];
        Marshal.Copy(p, b, 0, len);
        return Encoding.UTF8.GetString(b);
    }

    static string Utf8Z(IntPtr p)
    {
        if (p == IntPtr.Zero) return null;
        int len = 0;
        while (Marshal.ReadByte(p, len) != 0) len++;
        return Utf8(p, len);
    }

    public static List<OrderedDictionary> Query(string path, string sql)
    {
        IntPtr db;
        if (sqlite3_open_v2(Utf8Z(path), out db, SQLITE_OPEN_READONLY, IntPtr.Zero) != 0)
            throw new Exception("open failed: " + path);
        try
        {
            IntPtr stmt;
            if (sqlite3_prepare_v2(db, Utf8Z(sql), -1, out stmt, IntPtr.Zero) != 0)
                throw new Exception("prepare failed: " + Utf8Z(sqlite3_errmsg(db)) + " :: " + sql);
            var rows = new List<OrderedDictionary>();
            try
            {
                int n = sqlite3_column_count(stmt);
                int rc;
                while ((rc = sqlite3_step(stmt)) == SQLITE_ROW)
                {
                    var row = new OrderedDictionary();
                    for (int i = 0; i < n; i++)
                    {
                        string name = Utf8Z(sqlite3_column_name(stmt, i));
                        object v;
                        switch (sqlite3_column_type(stmt, i))
                        {
                            case SQLITE_INTEGER: v = sqlite3_column_int64(stmt, i); break;
                            case SQLITE_FLOAT: v = sqlite3_column_double(stmt, i); break;
                            case SQLITE_NULL: v = null; break;
                            default: v = Utf8(sqlite3_column_text(stmt, i), sqlite3_column_bytes(stmt, i)); break;
                        }
                        row[name] = v;
                    }
                    rows.Add(row);
                }
                if (rc != SQLITE_DONE)
                    throw new Exception("step failed: " + Utf8Z(sqlite3_errmsg(db)));
            }
            finally { sqlite3_finalize(stmt); }
            return rows;
        }
        finally { sqlite3_close(db); }
    }
}
'@
}

function Invoke-SqliteQuery([string]$Path, [string]$Sql) {
    return [WinSqlite]::Query($Path, $Sql)
}
