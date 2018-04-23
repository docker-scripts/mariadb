cmd_mariadb_help() {
    cat <<_EOF
    mariadb [ create | drop | dump | sql | script ]
        Manage the database of the container '$CONTAINER'.
        - create
              create the database '$DBNAME'
        - drop
              drop the database '$DBNAME'
        - dump
              dump the database '$DBNAME'
        - backup [<dbname>...]
              backup the given databases (default '$DBNAME')
        - restore <backup-file.tgz>
              restore databases from the given backup file
        - sql <query>
              run the given sql query on '$DBNAME'
        - script <file.sql>
              run the given sql script on '$DBNAME'

_EOF
}

cmd_mariadb() {
    [[ -n $DBHOST ]] || fail "Error: No DBHOST defined on 'settings.sh'"

    local cmd=$1
    shift
    case $cmd in
        sql)
            [[ -n $1 ]] || fail "Usage:\n$(cmd_mariadb_help)"
            ds @$DBHOST exec mysql -e "$1"
            ;;
        drop)
            ds @$DBHOST exec mysql -e "drop database if exists $DBNAME"
            ;;
        create)
            ds @$DBHOST exec mysql -e "
                create database if not exists $DBNAME;
                grant all privileges on $DBNAME.* to '$DBUSER'@'$CONTAINER.$NETWORK' identified by '$DBPASS';
                flush privileges; "
            ds @$DBHOST restart
            sleep 3
            ;;
        dump)
            ds @$DBHOST exec mysqldump --allow-keywords --opt $DBNAME
            ;;
        backup)
            # get the backup name
            local databases="$@"
            databases=${databases:-$DBNAME}
            local backup="$DBHOST-${databases// /-}-$(date +%Y%m%d)"

            # make the backup file
            ds @$DBHOST inject backup.sh $backup $databases

            # move the backup file to the current directory
            mv /var/ds/$DBHOST/$backup.tgz .
            ;;
        restore)
            # get the backup file
            local file=$1
            [[ -f $file ]] || fail "Usage:\n$(cmd_mariadb_help)"
            cp -f $file /var/ds/$DBHOST/

            # restore databases from the backup file
            ds @$DBHOST inject restore.sh $(basename $file)
            rm -f /var/ds/$DBHOST/$(basename $file)
            ;;
        script)
            [[ -n $1 ]] || fail "Usage:\n$(cmd_mariadb_help)"
            sqlfile=$1
            ds @$DBHOST exec sh -c "mysql --database=$DBNAME < /host/$sqlfile"
            ;;
        *)
            echo -e "Usage:\n$(cmd_mariadb_help)"
            exit
            ;;
    esac
}
