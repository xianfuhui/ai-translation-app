allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    if (project.name == "vosk_flutter") {
        afterEvaluate {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                namespace = "org.vosk.vosk_flutter"
                compileSdk = 36
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

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
