NAME=nullius
TRANSLATION_NAME=$(NAME)-ja
TRANSLATION_VERSION=$(shell jq -rM .version < info.json)

dist:
	git archive --prefix $(TRANSLATION_NAME)_$(TRANSLATION_VERSION)/ $(RELEASE_TAG) -o $(TRANSLATION_NAME)_$(TRANSLATION_VERSION).zip
clean:
	-rm -v $(TRANSLATION_NAME)_*.zip

latest-version:
	NAME="$(NAME)" ./tools/latest-version > $@

download-latest: latest-version
	./tools/download-latest

update-locale-en:
	./tools/update-local-en
