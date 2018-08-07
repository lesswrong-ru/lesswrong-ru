# LessWrong.ru

Этот репозиторий - точка входа для всех работ по сайту [lesswrong.ru](http://lesswrong.ru).

При этом репозитории - ansible-конфиги.

Код подпроектов в отдельных репозиториях:

* [lwcustom](https://github.com/lesswrong-ru/lwcustom) - drupal-модуль с php-кодом
* [drupal-theme-ng](https://github.com/lesswrong-ru/drupal-theme-ng) - drupal-тема
* [clippy](https://github.com/lesswrong-ru/clippy) - slack-бот
* [slack-search](https://github.com/lesswrong-ru/slack-search) - вьюер slack-архивов

Зато в этом репозитории есть описание задач, читайте [Issues](https://github.com/lesswrong-ru/lesswrong-ru/issues).

# Ansible

Ansible - это система управления конфигурациями на Python и YAML-конфигах.

Постепенно переводим всю конфигурацию сайта lesswrong.ru на Ansible.

Почему это хорошо:

* Воспроизводимость конфигурации (правильно написанные ansible-конфиги идемпотентны, повторный запуск ничего не ломает; при потере сервера можно будет быстро восстановить всю среду)
* Документация конфигурации (прочитав конфиги, можно понять, что как настроено)
* Версионирование (можно посмотреть историю, когда мы что и как перенастроили)
* Возможность поднять тестовую среду
* Потенциальная возможность развернуть копию сайта у себя для разработки

Использование Ansible сводится к тому, что вы чекаутите к себе этот репозиторий, настраиваете среду (см. ниже), правите конфиги (по необходимости) и запускаете команду, которая выкладывает новые конфиги.

В отличие от Chef и Puppet, у Ansible нет централизованного сервера, вся система сводится к синхронному запуску python-скриптов (генерируемых через ansible) на удалённых машинах.

## Как настроить

1. Убедитесь, что у вас установлен python2.7 и virtualenv.
2. `virtualenv venv`
3. `. ./venv/bin/activate`
4. `pip install -r ./requirements.txt`

## Как использовать

`ansible-playbook site.yml` (обязательно при активированном virtualenv).

Если вы хотите запустить только часть конфигов: `ansible-playbook site.yml --tags TAG`.

Список актуальных тегов можно найти в файле `site.yml`.

## Важные файлы (для тех, кто не хочет изучать весь Ansible)

* [nginx-конфиг](/lesswrong-ru/lesswrong-ru/blob/master/roles/website/templates/nginx)
* [Конфиг mediawiki](/lesswrong-ru/lesswrong-ru/blob/master/roles/wiki/templates/LocalSettings.php)
