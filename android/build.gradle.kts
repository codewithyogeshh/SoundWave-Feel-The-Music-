allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    plugins.withId("com.android.library") {
        try {
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val content = manifestFile.readText()
                if (content.contains("package=")) {
                    val newContent = content.replace(Regex("""package="[^"]*""""), "")
                    manifestFile.writeText(newContent)
                }
            }

            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val setCompileSdkVersion = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    setCompileSdkVersion.invoke(androidExt, 34)
                } catch (_: Exception) {}

                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(androidExt) == null) {
                    val ns = if (project.name.contains("on_audio_query")) {
                        "com.lucasjosino.on_audio_query"
                    } else {
                        "com.soundwave.plugin.${project.name.replace('-', '_')}"
                    }
                    setNamespace.invoke(androidExt, ns)
                }
            }
        } catch (_: Exception) {}
    }

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    project.tasks.whenTaskAdded {
        if (name.contains("compile") && name.contains("Kotlin")) {
            try {
                val getKotlinOptions = javaClass.getMethod("getKotlinOptions")
                val kotlinOptions = getKotlinOptions.invoke(this)
                val setJvmTarget = kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java)
                setJvmTarget.invoke(kotlinOptions, "17")
            } catch (_: Exception) {}
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
