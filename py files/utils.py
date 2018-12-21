from scipy.special import factorial

def float2fix(fl):
    fi = 0
    if fl < 0:
        fi += 1 << 31
    fi += int(abs(fl)) << 15
    fi += int((abs(fl) - int(abs(fl)))*32768)
    return fi

def taylor_e(x, order=3):
    ret = 1
    for i in range(1,order + 1):
        print(x**i / factorial(i))
        ret += x**i / factorial(i)
    return ret
