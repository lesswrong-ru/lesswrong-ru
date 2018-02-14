#!/bin/bash

# TODO nginx config

set -e

PROD=/srv/lesswrong.ru
DEV=/srv/dev.lesswrong.ru
DEV_NEW=/srv/dev.lesswrong.ru-new
DEV_OLD=/srv/dev.lesswrong.ru-old

if [[ -z "$DB_PASSWORD" ]]; then
    echo "DB_PASSWORD should be set to mysql root password"
    exit
fi
if [[ -z "$DEV_PASSWORD" ]]; then
    echo "DEV_PASSWORD should be set to mysql dev password (common for all dev DBs)"
    exit
fi

copy_files() {
    echo "Copying files..."
    rm -rf $DEV_NEW
    cp -rp $PROD $DEV_NEW

    local ROBOTS=$DEV_NEW/robots.txt
    rm -f $ROBOTS
    echo 'User-agent: *' >>$ROBOTS
    echo 'Disallow: /' >>$ROBOTS
}

init_mysql_users() {
    echo "Initializing MySQL users..."
    for DB in lw_dev wiki_dev forum_dev; do
        local USER=$DB
        mysql -uroot -p"$DB_PASSWORD" <<EOF
CREATE USER IF NOT EXISTS '$USER'@'localhost' IDENTIFIED BY '$DEV_PASSWORD';
GRANT ALL ON $DB.* TO '$USER'@'localhost' WITH GRANT OPTION;
EOF
    done
}

copy_db() {
    echo "Copying MySQL databases..."
    for DB in lw wiki forum; do
        # mysqldbcopy is broken because of https://bugs.mysql.com/bug.php?id=72951
        # mysqldbcopy --drop-first --source=root:"$DB_PASSWORD"@localhost --destination="$DB"_dev:"$DEV_PASSWORD"@localhost "$DB":"$DB"_dev
        mysqldump -uroot -p"$DB_PASSWORD" "$DB" | mysql -u"$DB"_dev -p"$DEV_PASSWORD" "$DB"_dev
    done
}

die() {
    echo "$1"
    exit 1
}

check_file() {
    if ! grep -q "$1" "$2"; then
        die "$1 not found in $2"
    fi
}

fix_drupal_config() {
    local DB_LINE="'database' => 'lw_dev'"
    local USER_LINE="'username' => 'lw_dev'"
    local PASS_LINE="'password' => '$DEV_PASSWORD'"
    local URL_LINE="\$base_url = 'https://dev.lesswrong.ru'"

    local FILE="$DEV_NEW/sites/default/settings.php"

    sed -i -e "s/'database' => 'lw'/$DB_LINE/" "$FILE"
    sed -i -e "s/'username' => 'lw'/$USER_LINE/" "$FILE"
    sed -i -e "s/'password' => '.*'/$PASS_LINE/" "$FILE"
    sed -i -e "s|\$base_url = 'https://lesswrong\.ru'|$URL_LINE|" "$FILE"

    check_file "$DB_LINE" "$FILE"
    check_file "$USER_LINE" "$FILE"
    check_file "$PASS_LINE" "$FILE"
    check_file "$URL_LINE" "$FILE"
}

fix_wiki_config() {
    local DB_LINE='$wgDBname = "wiki_dev"'
    local USER_LINE='$wgDBuser = "wiki_dev"'
    local PASS_LINE="\$wgDBpassword = \"$DEV_PASSWORD\""
    local WIKI_URL_LINE='$wgWikiUrl = "https://dev.lesswrong.ru/wiki/"';
    local SERVER_URL_LINE='$wgServer = "https://dev.lesswrong.ru"';
    local FILE="$DEV_NEW/wiki/LocalSettings.php"

    sed -i -e "s/\$wgDBname = \"wiki\"/$DB_LINE/" "$FILE"
    sed -i -e "s/\$wgDBuser = \"wiki\"/$USER_LINE/" "$FILE"
    sed -i -e "s/\$wgDBpassword = \".*\"/$PASS_LINE/" "$FILE"
    sed -i -e "s/\$wgWikiUrl\s\+= \".*\"/${WIKI_URL_LINE//\//\\/}/" "$FILE" # here and further: quoting via https://stackoverflow.com/a/27788661
    sed -i -e "s/\$wgServer = \".*\"/${SERVER_URL_LINE//\//\\/}/" "$FILE"

    check_file "$DB_LINE" "$FILE"
    check_file "$USER_LINE" "$FILE"
    check_file "$PASS_LINE" "$FILE"
    check_file "$WIKI_URL_LINE" "$FILE"
    check_file "$SERVER_URL_LINE" "$FILE"
}

fix_forum_config() {
    local DB_LINE='$db_name = "forum_dev"'
    local USER_LINE='$db_user = "forum_dev"'
    local PASS_LINE="\$db_passwd = \"$DEV_PASSWORD\""
    local URL_LINE="\$boardurl = 'https://dev.lesswrong.ru/forum'"
    local FILE="$DEV_NEW/forum/Settings.php"

    sed -i -e "s|\$db_name = 'forum'|$DB_LINE|" "$FILE"
    sed -i -e "s|\$db_user = 'forum'|$USER_LINE|" "$FILE"
    sed -i -e "s|\$db_passwd = '.*'|$PASS_LINE|" "$FILE"
    sed -i -e "s|\$boardurl = 'https://lesswrong\.ru/forum'|$URL_LINE|" "$FILE"
    sed -i -e "s|/srv/lesswrong\.ru|$DEV|" "$FILE"

    check_file "$DB_LINE" "$FILE"
    check_file "$USER_LINE" "$FILE"
    check_file "$PASS_LINE" "$FILE"

    rm -f "$DEV_NEW/forum/Settings_bak.php"
    rm -rf "$DEV_NEW/forum/cache"

    # TODO fix url
    # TODO fix boarddir, sourcedir, cachedir
}
fix_configs() {
    echo "Fixing configs..."
    fix_drupal_config
    fix_wiki_config
    fix_forum_config
}

patch_db() {
    mysql -u"lw_dev" -p"$DEV_PASSWORD" lw_dev -e "DELETE FROM rules_config WHERE name IN ('rules_slack_notifications_for_new_translations', 'rules_slack_translation_edit', 'rules_email_berekuk_on_new_content')"
}

copy_nginx() {
    echo "Copying nginx config..."
    local TMP_CONFIG=/tmp/nginx-dev.lesswrong.ru
    cp /etc/nginx/sites-enabled/lesswrong-ru $TMP_CONFIG

    sed -i -e 's/lesswrong.ru/dev.lesswrong.ru/' $TMP_CONFIG

    mv $TMP_CONFIG /etc/nginx/sites-enabled/dev.lesswrong.ru

    systemctl restart nginx
}

clear_cache() {
    cd $DEV_NEW && rm -rf cache && drush cc all
}

check_correctness() {
    echo "Checking for correctness.."
    grep -r srv/lesswrong.ru --exclude-dir={files,files-new,survey} "$DEV_NEW" && die "/srv/lesswrong.ru shouldn't be mentioned anywhere!" || true
    grep -r //lesswrong.ru --exclude-dir={files,files-new,survey} --exclude agreement.txt --exclude agreement.russian-utf8.txt "$DEV_NEW" && die "lesswrong.ru URL shouldn't be mentioned anywhere!" || true
}

commit_files() {
    echo "Commiting new files..."
    if [[ -e "$DEV_OLD" ]]; then
        rm -rf $DEV_OLD
    fi
    if [[ -e "$DEV" ]]; then
        mv $DEV $DEV_OLD
    fi
    mv $DEV_NEW $DEV
}

[[ -z "$SKIP_INIT_MYSQL" ]] && init_mysql_users
[[ -z "$SKIP_FILES" ]] && copy_files
[[ -z "$SKIP_DB" ]] && copy_db
[[ -z "$SKIP_CONFIGS" ]] && fix_configs
[[ -z "$SKIP_PATCH_DB" ]] && patch_db
[[ -z "$SKIP_NGINX" ]] && copy_nginx
[[ -z "$SKIP_CLEAR_CACHE" ]] && clear_cache

check_correctness

commit_files

echo "All done!"
