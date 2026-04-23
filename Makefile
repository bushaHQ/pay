SHARED_HTML = shared/busha_pay_checkout.html

# Copy shared assets into each SDK
.PHONY: sync
sync:
	@mkdir -p flutter/assets && cp $(SHARED_HTML) flutter/assets/busha_pay_checkout.html
	@mkdir -p android/pay-android/src/main/assets && cp $(SHARED_HTML) android/pay-android/src/main/assets/busha_pay_checkout.html
	@mkdir -p ios/Sources/BushaPay/Resources && cp $(SHARED_HTML) ios/Sources/BushaPay/Resources/busha_pay_checkout.html
	@mkdir -p react-native/assets && cp $(SHARED_HTML) react-native/assets/busha_pay_checkout.html

# Build each SDK
.PHONY: build-flutter build-android build-ios build-rn

build-flutter: sync
	cd flutter && flutter pub get && flutter analyze

build-android: sync
	cd android && ./gradlew :pay-android:assembleRelease

build-ios: sync
	cd ios && swift build

build-rn: sync
	cd react-native && npm ci && npm run build

# Publish
.PHONY: publish-flutter publish-android publish-ios publish-rn

publish-flutter: build-flutter
	cd flutter && flutter pub publish

publish-android: build-android
	cd android && ./gradlew :pay-android:publish

publish-ios:
	@echo "Tag and push — SPM picks it up from the Git tag"

publish-rn: build-rn
	cd react-native && npm publish

.PHONY: build-all publish-all clean
build-all: build-flutter build-android build-ios build-rn
publish-all: publish-flutter publish-android publish-ios publish-rn

clean:
	cd flutter && flutter clean || true
	cd android && ./gradlew clean || true
	cd ios && swift package clean || true
	cd react-native && rm -rf node_modules dist || true
