#!/bin/bash

# TODO nginx config

set -e

PROD=/srv/lesswrong.ru
DEV=/srv/dev.lesswrong.ru
DEV_NEW=/srv/dev.lesswrong.ru-new

if [[ -z "$DB_PASSWORD" ]]; then
    echo "DB_PASSWORD should be set to mysql root password"
    exit
fi
if [[ -z "$DEV_PASSWORD" ]]; then
    echo "DEV_PASSWORD should be set to mysql dev password (common for all dev DBs)"
    exit
fi

copy_files() {
    rm -rf $DEV_NEW
    cp -rp $PROD $DEV_NEW
}

copy_db() {
    mysqldbcopy --drop-first --source=root:"$DB_PASSWORD"@localhost --destination=root:"$DB_PASSWORD"@localhost lw:lw_dev
    mysqldbcopy --drop-first --source=root:"$DB_PASSWORD"@localhost --destination=root:"$DB_PASSWORD"@localhost wiki:wiki_dev
    mysqldbcopy --drop-first --source=root:"$DB_PASSWORD"@localhost --destination=root:"$DB_PASSWORD"@localhost forum:forum_dev
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
    local URL_LINE="$base_url = 'https://dev.lesswrong.ru'"

    local FILE="$DEV_NEW/sites/default/settings.php"

    sed -i -e "s/'database' => 'lw'/$DB_LINE/" "$FILE"
    sed -i -e "s/'username' => 'lw'/$USER_LINE/" "$FILE"
    sed -i -e "s/'password' => '.*'/$PASS_LINE/" "$FILE"
    sed -i -e "s/\$base_url = 'https:\/\/lesswrong\.ru'/${URL_LINE//\//\\/}/" "$FILE" # here and further: quoting via https://stackoverflow.com/a/27788661

    check_file "$DB_LINE" "$FILE"
    check_file "$USER_LINE" "$FILE"
    check_file "$PASS_LINE" "$FILE"
    check_file "$URL_LINE" "$FILE"

    rm -rf "$DEV_NEW/cache"
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
    sed -i -e "s/\$wgWikiUrl\s\+= \".*\"/${WIKI_URL_LINE//\//\\/}/" "$FILE"
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

    sed -i -e "s/\$db_name = 'forum'/$DB_LINE/" "$FILE"
    sed -i -e "s/\$db_user = 'forum'/$USER_LINE/" "$FILE"
    sed -i -e "s/\$db_passwd = '.*'/$PASS_LINE/" "$FILE"
    sed -i -e "s/\$boardurl = 'https?:\/\/lesswrong\.ru\/forum'/${URL_LINE//\//\\/}/" "$FILE"
    sed -i -e "s/\/srv\/lesswrong\.ru\//${DEV//\//\\/}/" "$FILE"

    check_file "$DB_LINE" "$FILE"
    check_file "$USER_LINE" "$FILE"
    check_file "$PASS_LINE" "$FILE"

    rm -f "$DEV_NEW/forum/Settings_bak.php"
    rm -rf "$DEV_NEW/forum/cache"

    # TODO fix url
    # TODO fix boarddir, sourcedir, cachedir
}
fix_configs() {
    fix_drupal_config
    fix_wiki_config
    fix_forum_config
}

copy_nginx() {
    local TMP_CONFIG=/tmp/nginx-dev.lesswrong.ru
    cp /etc/nginx/sites-enabled/lesswrong-ru $TMP_CONFIG

    sed -i -e 's/lesswrong.ru/dev.lesswrong.ru/' $TMP_CONFIG

    mv $TMP_CONFIG /etc/nginx/sites-enabled/dev.lesswrong.ru

    systemctl restart nginx
}

check_correctness() {
    grep -r srv/lesswrong.ru --exclude-dir={files,files-new,survey} "$DEV_NEW" && die "/srv/lesswrong.ru shouldn't be mentioned anywhere!"
    grep -r //lesswrong.ru --exclude-dir={files,files-new,survey} --exclude agreement.txt --exclude agreement.russian-utf8.txt "$DEV_NEW" && die "lesswrong.ru URL shouldn't be mentioned anywhere!"
}

[[ -z "$SKIP_FILES" ]] && copy_files
[[ -z "$SKIP_DB" ]] && copy_db
[[ -z "$SKIP_CONFIGS" ]] && fix_configs
[[ -z "$SKIP_NGINX" ]] && copy_nginx

check_correctness

# TODO move DEV_NEW to DEV
