#!/bin/sh

OLD_EMAIL=$1
CORRECT_NAME=$2
CORRECT_EMAIL=$3
shift 3
if [ -z "$OLD_EMAIL" ]; then
	echo "old email is missing"
	exit 1
fi
if [ -z "$CORRECT_NAME" ]; then
	echo "correct name is missing"
	exit 2
fi
if [ -z "$CORRECT_EMAIL" ]; then
	echo "correct email is missing"
	exit 3
fi
echo "re-writing history of '${OLD_EMAIL}' to '${CORRECT_NAME}'(${CORRECT_EMAIL})"
git filter-branch --env-filter "
	if [ \"\$GIT_COMMITTER_EMAIL\" = \"${OLD_EMAIL}\" ]
	then
	    export GIT_COMMITTER_NAME=\"${CORRECT_NAME}\"
	    export GIT_COMMITTER_EMAIL=\"${CORRECT_EMAIL}\"
	fi
	if [ \"\$GIT_AUTHOR_EMAIL\" = \"${OLD_EMAIL}\" ]
	then
	    export GIT_AUTHOR_NAME=\"${CORRECT_NAME}\"
	    export GIT_AUTHOR_EMAIL=\"${CORRECT_EMAIL}\"
	fi
	" $@ --tag-name-filter cat -- --branches --tags
