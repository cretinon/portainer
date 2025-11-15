#!/bin/bash

# shellcheck source=/dev/null disable=SC2294


#
# DOC : purpose of this lib is mainly to
# DOC : * install portainer
# DOC : * create/update/delete stack
# DOC : * start/stop stack
#
# DOC : api call ref https://app.swaggerhub.com/apis/portainer/portainer-ce/2.27.1
#

#
# usage: _get_endpoint_id
#
_get_endpoint_id () {
    _func_start

    local __id
    local __return
    local __url="$PORTAINER_URL/api/endpoints"
    local __header="X-API-Key: $PORTAINER_TOKEN"

    __response=$(_curl "GET" "$__url" "$__header")
    __return=$?

    if [ $__return != 0 ] ; then _error "something went wrong in curl" ; _func_end "$__return" ; return $__return ; fi # no _shellcheck

    __id=$(echo "$__response" | jq '.[] | .Id')

    _debug "id:$__id"

    echo "$__id"

    _func_end "$__return" ; return $__return
}

#
# usage: _get_stack
#
_get_stack () {
    _func_start

    local __stack
    local __url="$PORTAINER_URL/api/stacks"
    local __header="X-API-Key: $PORTAINER_TOKEN"

    __stack=$(_curl "GET" "$__url" "$__header" | jq -r '.[] | .Name')

    _debug "result:$__stack"

    echo "$__stack"

    _func_end "0" ; return 0
}

#
# usage: _get_stack_id_from_name --stack_name name ($1)
#
_get_stack_id_from_name () {
    _func_start

    if _notexist "$1"; then _error "stack_name EMPTY"; _func_end "1" ; return 1; fi
    if ! _get_stack | $GREP "$1" > /dev/null; then _warning "stack_name:$1 unknown"; fi

    _debug "stack_name:$1"

    local __id
    local __url="$PORTAINER_URL/api/stacks"
    local __header="X-API-Key: $PORTAINER_TOKEN"

    __id=$(_curl "GET" "$__url" "$__header" | jq '.[] | select(.Name == "$1")' | jq '.Id')

    _debug "result:""$__id"

    echo "$__id"

    _func_end "0" ; return 0
}

#
# usage: _get_stack_name_from_id --stack_id id ($1)
#
_get_stack_name_from_id () {
    _func_start

    if _notexist "$1"; then _error "stack_id EMPTY"; _func_end "1" ; return 1; fi

    _debug "stack_id:$1"

    local __name
    local __url="$PORTAINER_URL/api/stacks"
    local __header="X-API-Key: $PORTAINER_TOKEN"

    __name=$(_curl "GET" "$__url" "$__header" | jq -r '.[] | select(.Id == '"$1"') | .Name')

    _debug "result:""$__name"

    echo "$__name"

    _func_end "0" ; return 0
}

#
# usage: _stack_create --stack_name name ($1) --yaml_file file ($2)
#
_stack_create () {
    _func_start

    if _notexist "$1"; then _error "stack_name EMPTY"; _func_end "1" ; return 1; fi
    if _notexist "$2"; then _error "yaml_file EMPTY"; _func_end "1" ; return 1; fi
    if _filenotexist "$2"; then _error "yaml_file doesnt exist" ; _func_end "1" ; return 1; fi

    _debug "stack_name:$1"
    _debug "yaml_file:$2"

    local __id
    local __stack_name
    local __one_line_yaml
    local __response
    local __url
    local __header
    local __data
    local __data_type

    __id=$(_get_stack_id_from_name "$1")

    if _exist "$__id"; then
        _warning "stack_name already exist"
    else
        __id=$(_get_endpoint_id)
        __stack_name="$1"
        __one_line_yaml=$(< "$2" yq -R)

        __url="$PORTAINER_URL/api/stacks/create/standalone/string?endpointId=$__id"
        __header="X-API-Key: $PORTAINER_TOKEN"
        __data_type="Content-Type: text/plain"
        __data='{
  "fromAppTemplate": false,
  "name": "'$__stack_name'",
  "stackFileContent": '"$__one_line_yaml"'
}'

        __response=$(_curl "POST" "$__url" "$__header" "$__data_type" "$__data")

        _debug "response:""$__response"
    fi

    echo "$__response" | jq -M

    _func_end "0" ; return 0
}

#
# usage: _stack_update --stack_name name ($1) --yaml_file file ($2)
#
_stack_update () {
    _func_start

    if _notexist "$1"; then _error "stack_name EMPTY" ; _func_end "1" ; return 1 ; fi
    if _notexist "$2"; then _error "yaml_file EMPTY" ; _func_end "1" ; return 1 ; fi
    if _filenotexist "$2"; then _error "yaml_file doesnt exist"; _func_end "1" ; return 1 ; fi
    if _notinstalled "yq"; then _error "yq not found" ; _func_end "1" ; return 1 ; fi
    if _notinstalled "jq"; then _error "yq not found" ; _func_end "1" ; return 1 ; fi

    _debug "stack_name:$1"
    _debug "yaml_file:$2"

    local __id
    local __stack_name
    local __one_line_yaml
    local __stack_id
    local __response

    __id=$(_get_endpoint_id)
    __stack_name=$1
    __one_line_yaml=$(< "$2" yq -R)
    __stack_id=$(_get_stack_id_from_name "$1")

    __url="$PORTAINER_URL/api/stacks/$__stack_id?endpointId=$__id"
    __header="X-API-Key: $PORTAINER_TOKEN"
    __data_type="Content-Type: text/plain"
    __data='{
  "fromAppTemplate": false,
  "name": "'$__stack_name'",
  "stackFileContent": '"$__one_line_yaml"'
}'

    __response=$(_curl "PUT" "$__url" "$__header" "$__data_type" "$__data")

    _debug "response:""$__response"

    echo "$__response" | jq -M

    _func_end "0" ; return 0
}

#
# usage: _stack_delete --stack_name name ($1)
#
_stack_delete () {
    _func_start

    if _notexist "$1"; then _error "stack_name EMPTY" ; _func_end "1" ; return 1 ; fi

    _debug "stack_name:$1"

    local __id
    local __stack_name
    local __stack_id
    local __response

    __id=$(_get_endpoint_id)
    __stack_name=$1
    __stack_id=$(_get_stack_id_from_name "$1")

    __url="$PORTAINER_URL/api/stacks/$__stack_id?endpointId=$__id"
    __header="X-API-Key: $PORTAINER_TOKEN"

    __response=$(_curl "DELETE" "$__url" "$__header")

    _debug "response:""$__response"

    echo "$__response" | jq -M

    _func_end "0" ; return 0
}

#
# usage: _stack_start --stack_name name ($1)
#
_stack_start () {
    _func_start

    if _notexist "$1"; then _error "stack_name EMPTY" ; _func_end "1" ; return 1 ; fi

    _debug "stack_name:$1"

    local __id
    local __stack_name
    local __stack_id
    local __response

    __id=$(_get_endpoint_id)
    __stack_name=$1
    __stack_id=$(_get_stack_id_from_name "$1")

    __url="$PORTAINER_URL/api/stacks/$__stack_id/start?endpointId=$__id"
    __header="X-API-Key: $PORTAINER_TOKEN"

    __response=$(_curl "POST" "$__url" "$__header")

    _debug "response:""$__response"

    echo "$__response" | jq -M

    _func_end "0" ; return 0
}

#
# usage: _stack_stop --stack_name name ($1)
#
_stack_stop () {
    _func_start

    if _notexist "$1"; then _error "stack_name EMPTY"; _func_end "1" ; return 1 ; fi

    _debug "stack_name:$1"

    local __id
    local __stack_name
    local __stack_id
    local __response

    __id=$(_get_endpoint_id)
    __stack_name=$1
    __stack_id=$(_get_stack_id_from_name "$1")

    __url="$PORTAINER_URL/api/stacks/$__stack_id/stop?endpointId=$__id"
    __header="X-API-Key: $PORTAINER_TOKEN"

    __response=$(_curl "POST" "$__url" "$__header")

    _debug "response:""$__response"

    echo "$__response" | jq -M

    _func_end "0" ; return 0
}

#
# usage: _install
#
_install_portainer () {
    _func_start

    local __answer

    _volume_create "portainer_data"

    docker run -d -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:alpine

    _warning "Manual post-config, please do :"
    _warning " * open a browser to $PORTAINER_URL"
    _warning " * click on 'get started'"
    _warning " * click on 'User settings' > 'My account' > 'Access Tokens' > 'Add access token'"
    _warning " * create a new access token, copy it"

    while true; do
        read -r -p "Ready to continue ? (y/N) " __answer
        case $__answer in
            [Yy] )
                read -r -p "Paste your portainer Token " PORTAINER_TOKEN
                echo "PORTAINER_TOKEN=\"$PORTAINER_TOKEN\"" >  "$MY_GIT_DIR/portainer/conf"/my_portainer.conf
                break
                ;;
            * ) echo "Please get your Token";;
        esac
    done

    echo "PORTAINER_URL=\"https://$PORTAINER_URL:9000\"" >> "$MY_GIT_DIR/portainer/conf"/my_portainer.conf

    _func_end "0" ; return 0
}

#
# usage: _install_ci
#
_install_portainer_ci () {
    _func_start

    local __vol_name="portainer_ci"
    local __cont_tmp_name="tmpcont"
    local __cont_name="portainerci"
    local __cont_circleci_name
    local __cont_ip
    local __return

    if ! _volume_create "$__vol_name" 2> /dev/null ; then
        _error "something went wrong with volume create"; _func_end "1" ; return 1
    fi

    if ! docker run -d --name "$__cont_tmp_name" -v "$__vol_name:/data" cretinon/jinade_base:alpine sleep 1000 2> /dev/null ; then
        _error "something went wrong with docker run tmp_cont sleep 1000"; _func_end "1" ; return 1
    fi

    if ! docker cp "$MY_GIT_DIR/portainer/volume/portainer.tgz" "$__cont_tmp_name:/data/" 2> /dev/null ; then
        _error "something went wrong with docker cp"; _func_end "1" ; return 1
    fi

    if ! docker exec -u root -it "$__cont_tmp_name" /bin/sh -c "cd data;ls -ail; tar -zxv -f portainer.tgz" 2> /dev/null ; then
        _error "something went wrong when untar"; _func_end "1" ; return 1
    fi

    if ! docker stop "$__cont_tmp_name" 2> /dev/null ; then
        _error "something went wrong with docker stop tmp_cont"; _func_end "1" ; return 1
    fi

    if ! docker rm "$__cont_tmp_name" 2> /dev/null ; then
        _error "something went wrong with docker rm tmp_cont"; _func_end "1" ; return 1
    fi

    docker run -d -p 9000:9000 --name "$__cont_name" --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v "$__vol_name:/data" portainer/portainer-ce:alpine
    __return=$?

    __cont_ip=$(_container_get_ip "$__cont_name" "bridge")

    sed -i "$MY_GIT_DIR/portainer/conf/portainer.conf" -e 's/127.0.0.1/'"$__cont_ip"'/'

    if ! _load_conf "$MY_GIT_DIR/portainer/conf/portainer.conf"; then _error "something went wrong when loading portainer conf" ; _usage ; _func_end "1" ; return 1 ; fi

    __cont_circleci_name=$(_container_get_name_from_image "cimg/base:current")

    _container_connect_to_network "$__cont_circleci_name" "bridge"

    _func_end "$__return" ; return $__return
}

####################################################################################################
############################################# PROCESS ##############################################
####################################################################################################
_process_lib_portainer () {
    _func_start

    if ! _load_conf "$MY_GIT_DIR/portainer/conf/portainer.conf"; then _error "something went wrong when loading portainer conf" ; _usage ; _func_end "1" ; return 1 ; fi

    eval set -- "$@"

    local __return

    while true ; do
        case "$1" in
            --stack_name ) STACK_NAME=$2 ; shift ; shift ;;
            --stack_id )   STACK_ID=$2 ; shift ; shift ;;
            --yaml_file )  YAML_FILE=$2 ; shift ; shift ;;
            -- ) shift ; break ;;
            * ) shift ;;
        esac
    done

    while true ; do
        case "$1" in
            get_endpoint_id )        _get_endpoint_id ; __return=$? ; break ;;
            get_stack )	             _get_stack ; __return=$? ; break ;;
            get_stack_id_from_name ) _get_stack_id_from_name "$STACK_NAME" ; __return=$? ; break ;;
            get_stack_name_from_id ) _get_stack_name_from_id "$STACK_ID" ; __return=$? ; break ;;
            stack_create )           _stack_create "$STACK_NAME" "$YAML_FILE" ; __return=$? ; break ;;
            stack_update )	     _stack_update "$STACK_NAME" "$YAML_FILE" ; __return=$? ; break ;;
            stack_delete )           _stack_delete "$STACK_NAME" ; __return=$? ; break ;;
            stack_start )	     _stack_start "$STACK_NAME" ; __return=$? ; break ;;
            stack_stop )	     _stack_stop "$STACK_NAME" ; __return=$? ; break ;;
            install )		     _install_portainer ; __return=$? ; break ;;
            install_ci )	     _install_portainer_ci ; __return=$? ; break ;;
            -- ) shift ;;
            *)  _error "command $1 not found" ; __return=1 ; break ;;
        esac
    done

    _func_end "$__return" ; return "$__return"
}
