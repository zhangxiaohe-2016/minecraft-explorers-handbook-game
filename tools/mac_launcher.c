/* Local native launcher. Keep the app beside .tools/ and explorer/. */
#include <mach-o/dyld.h>
#include <limits.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>

int main(void) {
    char path[PATH_MAX], root[PATH_MAX], engine[PATH_MAX], project[PATH_MAX];
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) != 0 || !realpath(path, root)) return 1;
    for (int i=0;i<4;i++) {
        char *slash = strrchr(root, '/');
        if (!slash) return 2;
        *slash = 0;
    }
    if (snprintf(engine,sizeof(engine),"%s/.tools/godot-4.7.2/Godot.app",root) >= sizeof(engine)) return 3;
    if (snprintf(project,sizeof(project),"%s/explorer",root) >= sizeof(project)) return 3;
    int log = open("/tmp/explorer-player.log",O_CREAT|O_WRONLY|O_TRUNC,0600);
    if (log >= 0) { dup2(log,1); dup2(log,2); close(log); }
    execl("/usr/bin/open","open","-n","-a",engine,"--args","--path",project,(char *)NULL);
    perror("Cannot launch Godot");
    return 4;
}
