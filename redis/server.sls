include:
  - redis.common


{% from "redis/map.jinja" import redis with context %}


{% set install_from   = redis.install_from|default('source') -%}
{% set svc_state      = salt['pillar.get']('redis:svc_state', 'running') -%}
{% set svc_onboot     = salt['pillar.get']('redis:svc_onboot', True) -%}


{% if install_from == 'source' %}


{% set user           = salt['pillar.get']('redis:user', 'redis') -%}
{% set group          = salt['pillar.get']('redis:group', user) -%}
{% set home           = salt['pillar.get']('redis:home', '/var/lib/redis') -%}
{% set bin            = salt['pillar.get']('redis:bin', '/usr/local/bin/redis-server') -%}

redis_group:
  group.present:
    - name: {{ group }}


redis_user:
  user.present:
    - name: {{ user }}
    - gid_from_name: True
    - home: {{ home }}
    - group: {{ group }}
    - require:
      - group: redis_group


redis-init-script:
  file.managed:
    - name: /etc/init/redis-server.conf
    - template: jinja
    - source: salt://redis/files/upstart.conf.jinja
    - mode: 0750
    - user: root
    - group: root
    - context:
        conf: /etc/redis/redis.conf
        user: {{ user }}
        bin: {{ bin }}
    - require:
      - sls: redis.common


redis-old-init-disable:
  cmd.wait:
    - name: update-rc.d -f redis-server remove
    - watch:
      - file: redis-init-script


redis-log-dir:
  file.directory:
    - name: /var/log/redis
    - mode: 755
    - user: {{ user }}
    - group: {{ group }}
    - makedirs: True
    - require:
      - user: redis_user


redis-server:
  file.managed:
    - name: /etc/redis/redis.conf
    - makedirs: True
    - template: jinja
    - source: salt://redis/files/redis-{{ redis.cfg_version }}.conf.jinja
    - require:
      - file: redis-init-script
      - cmd: redis-old-init-disable
  service.running:
    - watch:
      - file: redis-init-script
      - cmd: redis-old-init-disable
      - file: redis-server


{% else %}


redis_config:
  file.managed:
    - name: {{ redis.cfg_name }}
    - template: jinja
    - source: salt://redis/files/redis-{{ redis.cfg_version }}.conf.jinja
    - require:
      - pkg: {{ redis.pkg_name }}


redis_service:
  service.{{ svc_state }}:
    - name: {{ redis.svc_name }}
    - enable: {{ svc_onboot }}
    - watch:
      - file: {{ redis.cfg_name }}
    - require:
      - pkg: {{ redis.pkg_name }}


{% endif %}
