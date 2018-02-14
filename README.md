# LessWrong.ru

Этот репозиторий - точка входа для всех работ по сайту [lesswrong.ru](http://lesswrong.ru).

При этом кода тут пока что нет, он в отдельных репозиториях:

* [lwcustom](https://github.com/lesswrong-ru/lwcustom) - drupal-модуль с php-кодом
* [drupal-theme-ng](https://github.com/lesswrong-ru/drupal-theme-ng) - drupal-тема (в разработке)
* [drupal-theme](https://github.com/lesswrong-ru/drupal-theme) - drupal-тема (текущая, на движке [AdaptiveTheme](https://www.drupal.org/project/adaptivetheme))

Зато в этом репозитории есть описание задач, читайте [Issues](https://github.com/lesswrong-ru/lesswrong-ru/issues).

# Ansible

## Как настроить

1. Убедитесь, что у вас установлен python2.7 и virtualenv.
2. `virtualenv venv`
3. `. ./venv/bin/activate`
4. `pip install -r ./requirements.txt`

## Как использовать

`ansible-playbook site.yml`
