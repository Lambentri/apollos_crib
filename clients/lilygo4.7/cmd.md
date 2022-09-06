```shell
python3 fontconvert.py --compress RobotoCondensedRegular12 12 Roboto_Condensed/RobotoCondensed-Regular.ttf > RobotoCondensedRegular12.py
python3 fontconvert.py --compress RobotoCondensedRegular16 16 Roboto_Condensed/RobotoCondensed-Regular.ttf > RobotoCondensedRegular16.py
python3 fontconvert.py --compress RobotoCondensedRegular20 20 Roboto_Condensed/RobotoCondensed-Regular.ttf > RobotoCondensedRegular20.py
python3 fontconvert.py --compress RobotoCondensedLight12 12 Roboto_Condensed/RobotoCondensed-Light.ttf > RobotoCondensedLight12.py
python3 fontconvert.py --compress RobotoCondensedLight16 16 Roboto_Condensed/RobotoCondensed-Light.ttf > RobotoCondensedLight16.py
python3 fontconvert.py --compress RobotoCondensedLight20 20 Roboto_Condensed/RobotoCondensed-Light.ttf > RobotoCondensedLight20.py
```

A modified font convert was used here, with support for offsets-from-file

```shell
python3 fontconvert.py --interval fa-intervals-solid.json --compress fa16 16 fontawesome-free-6.2.0-desktop/otfs/Font\ Awesome\ 6\ Free-Solid-900.otf > FontAwesomeFreeSolid16.py
python3 fontconvert.py --interval fa-intervals-solid.json --compress fa20 20 fontawesome-free-6.2.0-desktop/otfs/Font\ Awesome\ 6\ Free-Solid-900.otf > FontAwesomeFreeSolid20.py
python3 fontconvert.py --interval fa-intervals-solid.json --compress fa28 28 fontawesome-free-6.2.0-desktop/otfs/Font\ Awesome\ 6\ Free-Solid-900.otf > FontAwesomeFreeSolid28.py
python3 fontconvert.py --interval fa-intervals-regular.json --compress fa16 16 fontawesome-free-6.2.0-desktop/otfs/Font\ Awesome\ 6\ Free-Regular-400.otf > FontAwesomeFreeRegular16.py
python3 fontconvert.py --interval fa-intervals-regular.json --compress fa20 20 fontawesome-free-6.2.0-desktop/otfs/Font\ Awesome\ 6\ Free-Regular-400.otf > FontAwesomeFreeRegular20.py
python3 fontconvert.py --interval fa-intervals-regular.json --compress fa28 28 fontawesome-free-6.2.0-desktop/otfs/Font\ Awesome\ 6\ Free-Regular-400.otf> FontAwesomeFreeRegular28.py
```

drop them onto the fs, the roboto ones may take a bit @ 115200 ;)

```shell
sudo ampy  --port /dev/ttyACM0 put RobotoCondensedRegular12.py
sudo ampy  --port /dev/ttyACM0 put RobotoCondensedRegular16.py
sudo ampy  --port /dev/ttyACM0 put RobotoCondensedRegular20.py
sudo ampy  --port /dev/ttyACM0 put RobotoCondensedLight12.py
sudo ampy  --port /dev/ttyACM0 put RobotoCondensedLight16.py
sudo ampy  --port /dev/ttyACM0 put RobotoCondensedLight20.py
sudo ampy  --port /dev/ttyACM0 put FontAwesomeFreeSolid16.py
sudo ampy  --port /dev/ttyACM0 put FontAwesomeFreeSolid20.py
sudo ampy  --port /dev/ttyACM0 put FontAwesomeFreeSolid28.py
sudo ampy  --port /dev/ttyACM0 put FontAwesomeFreeRegular16.py
sudo ampy  --port /dev/ttyACM0 put FontAwesomeFreeRegular20.py
sudo ampy  --port /dev/ttyACM0 put FontAwesomeFreeRegular28.py
sudo ampy  --port /dev/ttyACM0 put fb2.py

```