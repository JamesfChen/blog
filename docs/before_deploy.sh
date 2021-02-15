
encrypted_4c7563b9ab37_key=$1
encrypted_4c7563b9ab37_iv=$2

openssl aes-256-cbc -K $encrypted_4c7563b9ab37_key -iv $encrypted_4c7563b9ab37_iv -in id_rsa.enc -out ~/.ssh/id_rsa -d
chmod 600 ~/.ssh/id_rsa
echo -e "Host 101.200.36.88\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
git submodule update --init --recursive