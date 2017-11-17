#!/bin/bash

if [ -z "$NODE_ID" ]; then
    echo "NODE_ID is required"
    exit
fi
if [ -z "$REVISION_ID" ]; then
    echo "REVISION_ID is required"
    exit
fi

echo "Node: $NODE_ID, deleting from revision: $REVISION_ID"

for vid in $(drush sqlq "select vid from node_revision where nid = $NODE_ID and vid >= $REVISION_ID" | fgrep -v vid); do
    echo $vid
    drush ev "node_revision_delete($vid)"
done
