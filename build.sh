mkdir -p app/src/main/java/com/example/xboxmanager
echo "android.useAndroidX=true" > gradle.properties

cat << 'EOF' > settings.gradle.kts
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = "Xbox"
include(":app")
EOF

cat << 'EOF' > build.gradle.kts
plugins { id("com.android.application") version "8.2.2" apply false; id("org.jetbrains.kotlin.android") version "1.9.22" apply false }
EOF

cat << 'EOF' > app/build.gradle.kts
plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "com.example.xboxmanager"; compileSdk = 34
    defaultConfig { applicationId = "com.example.xboxmanager"; minSdk = 26; targetSdk = 34; versionCode = 1; versionName = "1.0" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation("androidx.core:core-ktx:1.13.1"); implementation("androidx.activity:activity-ktx:1.9.0")
    implementation("commons-net:commons-net:3.11.1"); implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("com.google.code.gson:gson:2.11.0"); implementation("androidx.documentfile:documentfile:1.0.1")
}
EOF

bash part2.sh
bash part3.sh
gradle wrapper --gradle-version 8.5
./gradlew assembleDebug
