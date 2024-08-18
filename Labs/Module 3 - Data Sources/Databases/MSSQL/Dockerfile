# Adventure Works Database on SQL Server 2019
FROM mcr.microsoft.com/mssql/server:2019-latest

# Note: This isn't a secure password, and please don't use this for production.
ENV SA_PASSWORD=Welcome123
ENV ACCEPT_EULA=Y

# Change to root user to run wget and move the file
USER root

RUN wget -progress=bar:force -q -O AdventureWorks2019.bak https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak \
   && chmod 777 AdventureWorks2019.bak \
   && mkdir /var/opt/mssql/backup \
   && cp AdventureWorks2019.bak /var/opt/mssql/backup/

# Change back to the mssql user to restore the database
USER mssql

# Launch SQL Server, confirm startup is complete, restore the database, then terminate SQL Server.
RUN ( /opt/mssql/bin/sqlservr & ) | grep -q "Service Broker manager has started" \
    && /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P ${SA_PASSWORD} -Q 'RESTORE DATABASE AdventureWorks2019 FROM DISK = "/var/opt/mssql/backup/AdventureWorks2019.bak" WITH MOVE "AdventureWorks2017" to "/var/opt/mssql/data/AdventureWorks2019.mdf", MOVE "AdventureWorks2017_Log" to "/var/opt/mssql/data/AdventureWorks2019_log.ldf", NOUNLOAD, STATS = 5' \
    && pkill sqlservr

CMD ["/opt/mssql/bin/sqlservr"]