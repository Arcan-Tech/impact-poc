#!/bin/bash

setup_env() {

  local env_file=".env"
  local example_file=".env.example"

  if [ -f "$env_file" ]; then
    set -a
    source "$env_file"
    set +a
  else
    echo "$env_file does not exist. Creating it from $example_file..."
    if [ ! -f "$example_file" ]; then
      echo "Error: $example_file not found."
      return 1
    fi

    cp "$example_file" "$env_file"
    tmp_file=$(mktemp)

    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*[^#]*_PASS= ]]; then
        key="${line%%=*}"
        random_pass=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)
        echo "${key}=${random_pass}" >> "$tmp_file"
      else
        echo "$line" >> "$tmp_file"
      fi
    done < "$env_file"

    mv "$tmp_file" "$env_file"
  fi
}

generate_password() {
  length="${1:-16}"  # Default length = 16 characters
  tr -dc 'A-Za-z0-9!@#$%^&*()_+=-[]{}?<>.,' < /dev/urandom | head -c "$length"
}

create_user() {
  user="${1:-arcan}"
  if [ -z "$2" ]; then
    echo "No user password was provided, randomly generating one"
    generated_pass=$(generate_password 16)
    pass=${generated_pass}
  else
    pass="$2"
  fi
  echo "Creating user '$user' with password: $pass"
  htpasswd -bBc ./nginx/.htpasswd "$user" "$pass"
  echo "Saving unencrypted information to nginx/.htpasswd"
}


dump_db(){
	echo "Shutting down database"
	docker exec graph-dataset neo4j stop || true
	local name=${1:-unknown}
	local name=neo4j_${name}_$(date +'%Y-%m-%d').dump
	local outfile=${OUTPUT_DIR}/${name}
	sleep 3
	echo "Writing dump to output file $outfile"
	docker exec -it dump-helper \
	  neo4j-admin database dump neo4j \
	  --overwrite-destination=true \
	  --to-path=/app/datasets
	mv -f ${OUTPUT_DIR}/neo4j.dump $outfile
	echo "Restarting Neo4j DB..."
	docker start graph-dataset
	wait_db
	echo "Done"
}

wait_db(){
	until cypher_shell "RETURN 1;"; do
		echo "Waiting for neo4j to start..."
		sleep 10
	done
}

switch_dataset(){
	file=$1
	if [ ! -f "$file" ]; then
		echo "Error: $file not found."
		return 1
	fi
	file_name=$(basename $file)
	echo "Restoring dataset $file"
	docker exec graph-dataset neo4j stop || true
	sleep 3
	docker exec -i dump-helper \
	  neo4j-admin database load neo4j \
	  --overwrite-destination=true --from-stdin < $file
	docker start graph-dataset
	wait_db
	echo "Done"
}

cypher_shell() {
	docker exec graph-dataset \
		cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASS" "${@}"
}

clean_db() {
	cypher_shell "MATCH (n) DETACH DELETE n;"
}

list_datasets() {
	# grep -P '(neo4j_)([a-zA-Z0-9\_-]*)\.dump' | sed -E 's/(neo4j_|\.dump)//g'
	ls ${OUTPUT_DIR}
}

setup_env

case "$1" in
    create_datasets) 
        shift
        create_datasets $@ ;;
    clean_db)
        shift
        clean_db $@ ;;
    switch_dataset)
        shift
        switch_dataset $@ ;;
    list_datasets)
        shift
        list_datasets $@ ;;
    dump_db)
        shift
        dump_db $@ ;;
    create_user)
	shift
	create_user $@ ;;
    setup_env)
        shift
        ;;
    *)
        echo "Unknown command: $1"
        echo "Available commands: create_datasets, switch_dataset, clean_db, dump_db, setup_env"
        exit 1
        ;;
esac

