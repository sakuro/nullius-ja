NAME=nullius
TRANSLATION_NAME=$(NAME)-ja
TRANSLATION_VERSION=$(shell jq -rM .version < info.json)

dist:
	git archive --prefix $(TRANSLATION_NAME)_$(TRANSLATION_VERSION)/ HEAD -o $(TRANSLATION_NAME)_$(TRANSLATION_VERSION).zip
clean:
	-rm -v $(NAME)_*.zip $(TRANSLATION_NAME)_*.zip
