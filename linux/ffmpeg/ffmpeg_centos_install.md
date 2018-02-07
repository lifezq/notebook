## Linux环境ffmpeg以及相应解码器安装

### 1. 首先安装系统编译环境

yum install -y automake autoconf libtool gcc gcc-c++  #CentOS

### 2. 编译所需源码包    
#### 2.1 - yasm     
汇编器，新版本的ffmpeg增加了汇编代码    

    wget http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz
    tar -xzvf yasm-1.3.0.tar.gz
    cd yasm-1.3.0
    ./configure
    make
    make install
    
#### 2.2 - lame：Mp3音频解码

    wget http://jaist.dl.sourceforge.net/project/lame/lame/3.99/lame-3.99.5.tar.gz
    tar -xzvf lame-3.99.5.tar.gz
    cd lame-3.99.5
    ./configure
    make
    make install
    
#### 2.3 - amr支持

    wget http://downloads.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.3.tar.gz
    tar -xzvf opencore-amr-0.1.3.tar.gz
    cd opencore-amr-0.1.3
    ./configure
    make
    make install
    
#### 2.4 - amrnb支持

    wget http://www.penguin.cz/~utx/ftp/amr/amrnb-11.0.0.0.tar.bz2
    tar -xjvf amrnb-11.0.0.0.tar.bz2
    cd amrnb-11.0.0.0
    ./configure
    make
    make install
    
#### 2.5 - amrwb支持

    wget http://www.penguin.cz/~utx/ftp/amr/amrwb-11.0.0.0.tar.bz2
    tar -xjvf amrwb-11.0.0.0.tar.bz2
    cd amrwb-11.0.0.0
    ./configure
    make
    make install
    
#### 2.6 - ffmpeg

    wget http://ffmpeg.org/releases/ffmpeg-2.5.3.tar.bz2
    tar -xjvf ffmpeg-2.5.3.tar.bz2
    cd ffmpeg-2.5.3
    ./configure --enable-libmp3lame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-version3 --enable-shared
    make
    make install
    
#### 2.7 - 加载配置  

最后写入config后，终端运行ffmpeg命令，出现success和已安装的扩展，则运行成功。

    ldconfig
    
#### 2.8 - 可能的问题

    [root@namenode1 ffmpeg-3.1.1]# ffmpeg
    ffmpeg: error while loading shared libraries: libavdevice.so.57: cannot open shared object file: No such file or directory

解决方法：

    > vim ~/.bashrc
    export FFMPEG_HOME=/usr/local/ffmpeg
    export PATH=$FFMPEG_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$FFMPEG_HOME/lib:/usr/local/lib
    
### 3. 使用方法

    ffmpeg -i 1.mp3 -ac 1 -ar 8000 1.amr  --MP3转换AMR
    ffmpeg -i 1.amr 1.mp3                 --AMR转换MP3

### 4. 附录：    
#### 4.1 - 附录1

ffmpeg默认安装目录为“/usr/local/lib”，有些64位系统下软件目录则为“/usr/lib64”，编译过程中可能会出现

ffmpeg: error while loading shared libraries: libmp3lame.so.0: cannot open shared object file: No such file or directory
等类似的错误，解决办法是建立软链接：

     ln -s /usr/local/lib/libmp3lame.so.0.0.0 /usr/lib64/libmp3lame.so.0
     
#### 4.2 - 附录2

如果出现以下提示
ffmpeg: error while loading shared libraries: libavdevice.so.54: cannot open shared object file: No such file or directory
可以通过如下方式查看ffmpeg的动态链接库哪些没有找到

```
ldd `which ffmpeg`
        libavdevice.so.54 => not found
        libavfilter.so.3 => not found
        libavformat.so.54 => not found
        libavcodec.so.54 => not found
        libswresample.so.0 => not found
        libswscale.so.2 => not found
        libavutil.so.51 => not found
        libm.so.6 => /lib64/libm.so.6 (0x00002ab7c0eb6000)
        libpthread.so.0 => /lib64/libpthread.so.0 (0x00002ab7c100b000)
        libc.so.6 => /lib64/libc.so.6 (0x00002ab7c1125000)
        /lib64/ld-linux-x86-64.so.2 (0x00002ab7c0d9a000)
```

如果类似于上面的输出内容，查找以上类库，会发现全部在/usr/local/lib/下
```
find /usr/local/lib/ | grep -E "libavdevice.so.54|libavfilter.so.3|libavcodec.so.54"
/usr/local/lib/libavfilter.so.3.17.100
/usr/local/lib/libavcodec.so.54.59.100
/usr/local/lib/libavdevice.so.54
/usr/local/lib/libavcodec.so.54
/usr/local/lib/libavfilter.so.3
/usr/local/lib/libavdevice.so.54.2.101
```

查看链接库配置文件   
    more  /etc/ld.so.conf | grep /usr/local/lib  
    
如果不包含的话，需要编辑此文添加：
      vi /etc/ld.so.conf
    /usr/local/lib
    /usr/local/lib64

运行配置命令
    ldconfig
    
关于ffmpeg简介：

FFmpeg是一个开源免费跨平台的视频和音频流方案，属于自由软件，采用LGPL或GPL许可证（依据你选择的组件）。它提供了录制、转换以及流化音视频的完整解决方案。它包含了非常先进的音频/视频编解码库libavcodec，为了保证高可移植性和编解码质量，libavcodec里很多codec都是从头开发的。其官方网址为：http://www.ffmpeg.org

最后，部分内容参照http://linux.it.net.cn/e/Linuxit/2014/0828/3980.html   

作者：iEpacJ    
链接：https://www.jianshu.com/p/277fc2300f1e   
來源：简书     
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
