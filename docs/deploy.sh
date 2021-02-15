#!/usr/bin/env bash

#use brew"s ruby
export PATH=/usr/local/bin:$PATH
SITE_DIR=./docs
CI_TOKEN=$1

#判断sit目录
#1.当git clone之后需要git submodule update更新site仓库，不过对于travis ci，会默认执行git submodule xxx来更新site仓库
#2.除非人为删除site目录，不然site目录不会被删除，jekyll build报错也不会删除site目录。
#基于上面的判断我们可以就不用担心site目录不是子仓库。如果由于某些不看抗拒的原因，导致site目录和blog目录不存在父子仓库关系时，
#我们应该这么做。
#- git clone git@github.com:HawksJamesf/blog.git -b gh-pages _site(如果不存在_site需要这样做)
#- 最后执行git remote add origin git@github.com:HawksJamesf/blog.git
#- 在blog目录(cd blog/)下执行 git submodule add -f git@github.com:HawksJamesf/blog.git _site
#- 在site目录(cd site/)下执行，git add .&&git commit -m update&& git push origin gh-pages
git config --global user.email "hawksjamesf@gmail.com"
git config --global user.name "jamesf chen"
jekyll build -d docs
if [ ! -d $SITE_DIR ];then
	echo "not exit $SITE_DIR"
	exit 1
fi

NOTHING_TO_COMMIT="nothing to commit, working tree clean"
isExit="false"
#post site
postSite(){
	cd $SITE_DIR
	# git checkout -b gh-pages
	# string=$(git add . && git commit -m update)
	isExit=`echo "$(git add . && git commit -m update)"\
	|while read line
	do
		
		if [ "$line" ==  "$NOTHING_TO_COMMIT" ];then
			echo "true"
			break 
		fi
	done`
	# echo "$string" #格式化字符串，存在\n有效
	# echo $string  一行字符串，存在\n无效
	# echo "$isExit"
	if [ "$isExit" == "true" ];then
		echo -e "\033[34m $NOTHING_TO_COMMIT \033[0m"
		exit 1
	fi

	# git push --force origin HEAD:gh-pages
	git push --quiet --force https://$CI_TOKEN@github.com/JamesfChen/blog.git HEAD:gh-pages
	echo -e "\033[34m update successfully \033[0m"
}
postSite





