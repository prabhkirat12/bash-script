#!/bin/bash
 
log_file="user_creation.log"
 
# Function to log messages
log() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" | tee -a "$log_file"
}
 
# Function to create user
create_user() {
    local email="$1"
    local birth_date="$2"
    local groups="$3"
    local shared_folder="$4"
 
    # Extract username from email
    local username=$(echo "$email" | awk -F '@' '{print $1}' | awk -F '.' '{print substr($1, 1, 1) $2}')
 
    # Extract password from birth date
    local password=$(echo "$birth_date" | awk -F '/' '{print $2 $1}')
 
    log "Creating user: $username"
    log "Email: $email"
    log "Birth Date: $birth_date"
    log "Groups: $groups"
    log "Shared Folder: $shared_folder"
    log "Password: $password"
 
    # Add user creation logic here
    if sudo useradd -m -s /bin/bash -p "$(openssl passwd -1 "$password")" "$username"; then
        log "User $username created successfully."
    else
        log "Error creating user $username."
        return 1
    fi
 
   # Assign user to groups
if [[ -n "$groups" ]]; then
    IFS=' ' read -r -a group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)  # Trim whitespace
        if ! grep -q "^$group:" /etc/group; then
            if sudo groupadd "$group"; then
                log "Group $group created."
            else
                log "Error creating group $group."
            fi
        fi
        if sudo usermod -aG "$group" "$username"; then
            log "User $username added to group $group."
        else
            log "Error adding user $username to group $group."
        fi
    done
fi

 
    # Setup shared folder if provided
    if [[ -n "${shared_folder// }" ]]; then
        shared_folder=$(echo "$shared_folder" | xargs)  # Trim whitespace
        if sudo mkdir -p "$shared_folder"; then
            log "Shared folder $shared_folder created."
        fi
        if sudo chown "$username":"$username" "$shared_folder"; then
            log "Permissions set for shared folder $shared_folder."
        fi
        if sudo chmod 770 "$shared_folder"; then
            log "Permissions adjusted for shared folder $shared_folder."
        fi
        if sudo ln -s "$shared_folder" "/home/$username/shared"; then
            log "Link created for shared folder in /home/$username."
        fi
    fi
 
    # Enforce password change at first login
    if sudo chage -d 0 "$username"; then
        log "Password change enforced at first login for $username."
    fi
 
    # Create alias if user is in sudo group
    if [[ "$groups" == *"sudo"* ]]; then
        if echo "alias myls='ls -la'" | sudo tee -a "/home/$username/.bash_aliases" >/dev/null; then
            log "Alias 'myls' created for user $username."
        fi
    fi
}
 
# Function to prompt user for confirmation
confirm() {
    read -p "Are you sure you want to create $1 users? (yes/no): " choice
    case "$choice" in
        yes|Yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}
 
# Hardcoded CSV file path
file_path="users.csv"
 
if [[ ! -f "$file_path" ]]; then
    echo "File not found!"
    exit 1
fi
 
user_count=$(($(wc -l < "$file_path") - 1))
 
if confirm "$user_count"; then
    while IFS=';' read -r email birth_date groups shared_folder; do
        # Skip the header
        if [[ "$email" == "e-mail" ]]; then
            continue
        fi
 
        create_user "$email" "$birth_date" "$groups" "$shared_folder"
    done < "$file_path"
else
    echo "User creation aborted."
    exit 1
fi
