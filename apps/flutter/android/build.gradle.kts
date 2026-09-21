plugins {
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.5.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // Shizuku Maven repository
        maven {
            url = uri("https://raw.githubusercontent.com/RikkaApps/Shizuku-API/master/maven")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

allprojects {
    extra.set("compileSdkVersion", 36)
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
