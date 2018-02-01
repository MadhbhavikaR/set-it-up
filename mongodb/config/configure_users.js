mydb=db.getSiblingDB("admin");
mydb.createUser( {   user: "admin",   pwd: "test",   roles: [ { role: "userAdminAnyDatabase", db: "admin" } ] })